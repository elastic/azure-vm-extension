from typing import Counter
import unittest
import xmlrunner
from elasticsearch import Elasticsearch
import os
import time

class TestIndices(unittest.TestCase):

    es = Elasticsearch(
        [os.environ.get('ES_URL')],
        http_auth=(os.environ.get('ES_USERNAME'), os.environ.get('ES_PASSWORD')),
    )

    hostname = os.environ.get('VM_NAME')
    isWindows = "true" in os.getenv('TF_VAR_isWindows', 'true').lower()

    def countEnrolment(self, index_name, hostname, compareWith):
        tries = 1
        total = 20
        count = 0
        while count < compareWith:
            if tries > total:
                break
            print("countEnrolment: {} out of {}".format(tries, total))
            records_count = self.es.count(index=index_name,body={
                            "query": {
                                "bool": {
                                    "filter": [
                                        {
                                            "match_all": {}
                                        },
                                        {
                                            "match_phrase": {
                                                "local_metadata.host.hostname": hostname
                                            }
                                        },
                                        {
                                            "match_phrase": {
                                                "active": True
                                            }
                                        }
                                    ],
                                    "must_not": [
                                        {
                                            "match_phrase": {
                                                "policy_id": "policy-elastic-agent-on-cloud"
                                            }
                                        }
                                    ]
                                }
                            }
                        }
                    )
            count = records_count['count']
            if count >= compareWith:
                break
            tries += 1
            time.sleep(5)
            continue
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_count)
        return count

    def count(self, index_name, hostname, compareWith):
        tries = 1
        total = 20
        count = 0
        while count < compareWith:
            if tries > total:
                break
            print("count: {} out of {}".format(tries, total))
            records_count = self.es.count(index=index_name, body={"query": {"match": {"agent.hostname": hostname}}})
            count = records_count['count']
            if count >= compareWith:
                break
            tries += 1
            time.sleep(5)
            continue

        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_count)
        return count

    def exists(self, index_name):
        tries = 1
        total = 10
        exist = False
        while not exist:
            if tries > total:
                break
            print("exists: {} out of {}".format(tries, total))
            ## Deprecated to access system indices
            ## https://github.com/elastic/elasticsearch/issues/50251
            exist = self.es.indices.exists(index_name)
            if exist:
                break
            tries += 1
            time.sleep(5)
            continue
        return exist

    def countAndTest(self, index_name, hostname, compareWith):
        records_count = self.count(index_name, hostname, compareWith)
        self.assertTrue(records_count >= compareWith, "Expected at least one entry in index {}, got {}".format(index_name, records_count))

    def test_green_indices(self):
        records_indices = self.es.cat.indices()
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_indices)
        self.assertTrue("green" in records_indices, "Expected green indices")

    def test_indice_fleet_agents_7_exists(self):
        self.assertTrue(self.exists('.fleet-agents-7'), "Expected .fleet-agents-7 index")

    def test_enrolment(self):
        index_name = '.fleet-agents-7'
        compareWith = 1
        records_count = self.countEnrolment(index_name, self.hostname, compareWith)
        self.assertTrue(records_count >= compareWith, "Expected at least one entry in index {}, got {}".format(index_name, records_count))

    def test_indice_ds_metrics_memory(self):
        self.countAndTest('.ds-metrics-system.memory-default-*', self.hostname, 1)

    def test_indice_ds_metrics_cpu(self):
        self.countAndTest('.ds-metrics-system.cpu-default-*', self.hostname, 1)

    def test_indice_ds_metrics_diskio(self):
        self.countAndTest('.ds-metrics-system.diskio-default-*', self.hostname, 1)

    def test_indice_ds_logs_windows_diskio(self):
        if self.isWindows:
            self.countAndTest('.ds-logs-system.application-default-*', self.hostname, 1)

    def test_indice_ds_logs_linux_diskio(self):
        if not self.isWindows:
            self.countAndTest('.ds-logs-system.syslog-default-*', self.hostname, 1)

if __name__ == '__main__':
    unittest.main(testRunner=xmlrunner.XMLTestRunner(output='test-reports'))
