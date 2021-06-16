import unittest
import xmlrunner
from elasticsearch import Elasticsearch
from waiting import wait
import os

class TestIndices(unittest.TestCase):

    es = Elasticsearch(
        [os.environ.get('ES_URL')],
        http_auth=(os.environ.get('ES_USERNAME'), os.environ.get('ES_PASSWORD')),
    )

    hostname = os.environ.get('VM_NAME')
    ## TODO: Read from env variable
    isWindows = True

    def countEnrolment(self, index_name, hostname):
        return self.es.count(index=index_name,body={
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

    def count(self, index_name, hostname):
        return self.es.count(index=index_name, body={"query": {"match": {"agent.hostname": hostname}}})

    def countAndTest(self, index_name, hostname, compare):
        records_count = self.count(index_name, hostname)
        count = records_count['count']
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_count)
        self.assertTrue(count >= compare, "Expected at least one entry in index {}, got {}".format(index_name, count))

    def test_indice_fleet_agents_7_exists(self):
        index_name = '.fleet-agents-7'
        ## Let's wait a bit until the indices are ready
        wait(lambda: self.es.indices.exists(index_name), timeout_seconds=120, waiting_for="Index to be ready")

        ## Deprecated to access system indices
        ## https://github.com/elastic/elasticsearch/issues/50251
        self.assertTrue(self.es.indices.exists(index_name))

    def test_enrolment(self):
        index_name = '.fleet-agents-7'
        ## Let's wait a bit until the indices are ready
        wait(lambda: self.countEnrolment(index_name, self.hostname), timeout_seconds=120, waiting_for="Index to be ready")

        records_count = self.countEnrolment(index_name, self.hostname)
        count = records_count['count']
        ## Print will be shown in the junit xml as system-out. This should help to debug if needed.
        print(records_count)
        self.assertTrue(count >= 1, "Expected at least one entry in index {}, got {}".format(index_name, count))

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
