# API key authentication

The Linux and Windows handlers accept an encoded Elasticsearch API key in
`protectedSettings.apiKey`. The encoded value is the `encoded` field returned
by the Elasticsearch create API key API.

When loading current or previous extension settings, handlers select
credentials in this order:

1. `apiKey` using `Authorization: ApiKey <encoded-value>`
2. `username` and `password` using HTTP Basic authentication
3. `base64Auth` using HTTP Basic authentication

The selected credentials authenticate both the Elasticsearch version request
and all Kibana Fleet requests. Existing username/password and `base64Auth`
deployments therefore remain compatible.

## Required privileges

The runtime API key requires:

- Elasticsearch cluster privilege `monitor`, for `GET /`
- Kibana Fleet privilege `All`

The handler calls these authenticated endpoints during enable:

1. `GET {elasticsearch}/`
2. `POST {kibana}/api/fleet/setup`
3. `POST {kibana}/api/fleet/agents/setup` for stacks before 7.13
4. `GET {kibana}/api/fleet/agent_policies`
5. `POST {kibana}/api/fleet/agent_policies?sys_monitoring=true` when the policy is absent
6. `GET {kibana}/api/fleet/enrollment-api-keys`
7. `GET {kibana}/api/fleet/enrollment-api-keys/{id}`
8. `GET {kibana}/api/fleet/settings` for stacks with Fleet Server

The enrollment token returned by Fleet is used separately to enroll Elastic
Agent; the provisioning API key is not passed to the agent.
