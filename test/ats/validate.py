from typing import Counter
import unittest
import xmlrunner
from elasticsearch import Elasticsearch
from waiting import wait
import os
import time

class TestIndices(unittest.TestCase):

    es = Elasticsearch(
        [os.environ.get('ES_URL')],
        http_auth=(os.environ.get('ES_USERNAME'), os.environ.get('ES_PASSWORD')),
    )

    hostname = os.environ.get('VM_NAME')
    ## TODO: Read from env variable
    isWindows = True

    def countEnrolment(self, index_name, hostname):
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
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_count)
        return records_count['count']

    def count(self, index_name, hostname):
        records_count = self.es.count(index=index_name, body={"query": {"match": {"agent.hostname": hostname}}})
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_count)
        return records_count['count']

    def waitForCount(self, index_name, hostname, compare):
        count = 0
        while count < compare:
            count = self.count(index_name, hostname)
            time.sleep(5)
        return count >= compare

    def waitForCountEnrolment(self, index_name, hostname, compare):
        count = 0
        while count < compare:
            count = self.countEnrolment(index_name, hostname)
            time.sleep(5)
        return count >= compare

    def waitForIndexExist(self, index_name):
        exist = False
        while not self.es.indices.exists(index_name):
            time.sleep(5)
        return True

    def countAndTest(self, index_name, hostname, compare):
        ## Let's wait a bit until the indices are ready
        wait(lambda: self.waitForCount(index_name, self.hostname, compare), timeout_seconds=30, waiting_for="Index to be ready")
        records_count = self.count(index_name, hostname)
        self.assertTrue(records_count >= compare, "Expected at least one entry in index {}, got {}".format(index_name, records_count))

    def test_green_indices(self):
        records_indices = self.es.cat.indices()
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_indices)
        self.assertTrue("green" in records_indices)

    def test_indice_fleet_agents_7_exists(self):
        index_name = '.fleet-agents-7'
        ## Let's wait a bit until the indices are ready
        wait(lambda: self.waitForIndexExist(index_name), timeout_seconds=120, waiting_for="Index to be ready")

        ## Deprecated to access system indices
        ## https://github.com/elastic/elasticsearch/issues/50251
        self.assertTrue(self.es.indices.exists(index_name))

    def test_enrolment(self):
        index_name = '.fleet-agents-7'
        compare = 1
        ## Let's wait a bit until the indices are ready
        wait(lambda: self.waitForCountEnrolment(index_name, self.hostname, compare), timeout_seconds=120, waiting_for="Index to be ready")

        records_count = self.countEnrolment(index_name, self.hostname)
        self.assertTrue(records_count >= compare, "Expected at least one entry in index {}, got {}".format(index_name, records_count))

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
