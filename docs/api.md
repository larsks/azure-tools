# Linux and Azure Metadata REST API

The documentation for the [WALinuxAgent][] script, used to perform
initial system configuration on Linux instances running on the
[Azure][] platform, says:

> COMMUNICATION
> 
> The information flow from the platform to the agent occurs via two channels:
> 
> - A boot-time attached DVD for IaaS deployments.
>   This DVD includes an OVF-compliant configuration file that includes all
>   provisioning information other than the actual SSH keypairs.
> 
> - A TCP endpoint exposing a REST API used to obtain deployment and topology
>   configuration.

[walinuxagent]: https://github.com/Azure/WALinuxAgent
[azure]: https://azure.microsoft.com/en-us/

However, there appears to be no formal documentation for the REST API.
I spent some time looking at the code for the agent and running the
agent under [strace][].  This document is the result of my
investigation.

[strace]: https://en.wikipedia.org/wiki/Strace

## Configuration server

The IP address of the configuration server is discovered via DHCP option 245 provided in the Azure environment.  You can see this in `/var/log/waagent.log`:

    2016/04/16 02:50:12 IPv4 address: 100.115.176.25
    2016/04/16 02:50:12 MAC  address: 00:0D:3A:12:B1:15
    2016/04/16 02:50:12 Probing for Windows Azure environment.
    2016/04/16 02:50:12 DoDhcpWork: Setting socket.timeout=10, entering recv
    2016/04/16 02:50:12 Discovered Windows Azure endpoint: 100.115.176.3
    2016/04/16 02:50:12 Fabric preferred wire protocol version: 2015-04-05

If you look at the `DoDhcpWork` method in the `waagent` script, you can see that  this is a messy solution: the script needs to first stop any running DHCP client, then perform a DHCP query *in Python*, possibly mucking about with routes first, and then needs to undo any network changes and restart the DHCP client.

## REST API Endpoints

- `/?comp=versions` -- get a list of API versions supported by the configuration server.

  A request looks like:

        curl http://100.115.176.3/?comp=versions

  A response looks like:

        <?xml version="1.0" encoding="utf-8"?>
        <Versions>
          <Preferred>
            <Version>2015-04-05</Version>
          </Preferred>
          <Supported>
            <Version>2015-04-05</Version>
            <Version>2012-11-30</Version>
            <Version>2012-09-15</Version>
            <Version>2012-05-15</Version>
            <Version>2011-12-31</Version>
            <Version>2011-10-15</Version>
            <Version>2011-08-31</Version>
            <Version>2011-04-07</Version>
            <Version>2010-12-15</Version>
            <Version>2010-28-10</Version>
          </Supported>
        </Versions>

- `/machine/?comp=goalstate` -- return an XML document with information about available API configuration endpoints for this host.  Can except the `x-ms-version` HTTP header (`-H "x-ms-version: 2012-11-30"`) and the `x-ms-agent` header (which should be `WALinuxAgent`).

  A request looks like:

        curl http://100.115.176.3/machine/?comp=goalstate -H 'x-ms-agent-name: WALinuxAgent' -H 'x-ms-version: 2012-11-30'

  A response looks like:

        <?xml version="1.0" encoding="utf-8"?>
        <GoalState xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="goalstate10.xsd">
          <Version>2012-11-30</Version>
          <Incarnation>1</Incarnation>
          <Machine>
            <ExpectedState>Started</ExpectedState>
            <StopRolesDeadlineHint>300000</StopRolesDeadlineHint>
            <LBProbePorts>
              <Port>16001</Port>
            </LBProbePorts>
            <ExpectHealthReport>FALSE</ExpectHealthReport>
          </Machine>
          <Container>
            <ContainerId>a511aa6d-29e7-4f53-8788-55655dfe848f</ContainerId>
            <RoleInstanceList>
              <RoleInstance>
                <InstanceId>f6cd1d7ef1644557b9059345e5ba890c.lars-test-1</InstanceId>
                <State>Started</State>
                <Configuration>
                  <HostingEnvironmentConfig>http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&amp;type=hostingEnvironmentConfig&amp;incarnation=1</HostingEnvironmentConfig>
                  <SharedConfig>http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&amp;type=sharedConfig&amp;incarnation=1</SharedConfig>
                  <ExtensionsConfig>http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&amp;type=extensionsConfig&amp;incarnation=1</ExtensionsConfig>
                  <FullConfig>http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&amp;type=fullConfig&amp;incarnation=1</FullConfig>
                  <Certificates>http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=certificates&amp;incarnation=1</Certificates>
                  <ConfigName>f6cd1d7ef1644557b9059345e5ba890c.0.f6cd1d7ef1644557b9059345e5ba890c.0.lars-test-1.1.xml</ConfigName>
                </Configuration>
              </RoleInstance>
            </RoleInstanceList>
          </Container>
        </GoalState>

- `/machine/<container_id>/<instance_id>?comp=config&type=hostingEnvironmentConfig&incarnation=1`

  A request looks like:

        curl 'http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&type=hostingEnvironmentConfig&incarnation=1' -H "x-ms-version: 2012-11-30" -H "x-ms-agent-name: WALinuxAgent"

  A response looks like:

        <?xml version="1.0" encoding="utf-8"?>
        <HostingEnvironmentConfig version="1.0.0.0" goalStateIncarnation="1">
          <StoredCertificates>
            <StoredCertificate name="Cert0My" certificateId="sha1:65A6D1D84F048F358766291CA26FB715033AEAB4" storeName="My" configurationLevel="System" />
          </StoredCertificates>
          <Deployment name="f6cd1d7ef1644557b9059345e5ba890c" guid="{db132ce8-da09-4d62-a802-8f96304f2f25}" incarnation="0" isNonCancellableTopologyChangeEnabled="false">
            <Service name="lars-test-1" guid="{00000000-0000-0000-0000-000000000000}" />
            <ServiceInstance name="f6cd1d7ef1644557b9059345e5ba890c.0" guid="{5f60b5ac-c18b-409d-898f-457e0c68e3b4}" />
          </Deployment>
          <Incarnation number="1" instance="lars-test-1" guid="{ae4f8ba1-08d5-4e6c-ae67-6dd36d7b2114}" />
          <Role guid="{bfb200dd-637f-6714-805b-18c16799a4cd}" name="lars-test-1" hostingEnvironmentVersion="1" software="" softwareType="ApplicationPackage" entryPoint="" parameters="" settleTimeSeconds="0" />
          <HostingEnvironmentSettings name="full" Runtime="rd_fabric_stable_dhf4.150629-1102.RuntimePackage_1.0.0.14.zip">
            <CAS mode="full" />
            <PrivilegeLevel mode="max" /><AdditionalProperties><CgiHandlers></CgiHandlers></AdditionalProperties></HostingEnvironmentSettings>
          <ApplicationSettings>
            <Setting name="__ModelData" value="&lt;m role=&quot;lars-test-1&quot; xmlns=&quot;urn:azure:m:v1&quot;>&lt;r name=&quot;lars-test-1&quot;>&lt;e name=&quot;openInternalEndpoint&quot; />&lt;e name=&quot;ssh&quot; />&lt;/r>&lt;/m>" />
            <Setting name="ProvisionCertificate|Cert0My" value="sha1:65A6D1D84F048F358766291CA26FB715033AEAB4" />
          </ApplicationSettings>
        </HostingEnvironmentConfig>

- `/machine/<container_id>/<instance_id>?comp=config&type=sharedConfig&incarnation=1`

  A request looks like:

        curl -H "x-ms-version: 2012-11-30" -H "x-ms-agent-name: WALinuxAgent" 'http://100.115.176.3:80/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&type=sharedConfig&incarnation=1'

  A response looks like:

        <?xml version="1.0" encoding="utf-8"?>
        <SharedConfig version="1.0.0.0" goalStateIncarnation="1">
          <Deployment name="f6cd1d7ef1644557b9059345e5ba890c" guid="{db132ce8-da09-4d62-a802-8f96304f2f25}" incarnation="0" isNonCancellableTopologyChangeEnabled="false">
            <Service name="lars-test-1" guid="{00000000-0000-0000-0000-000000000000}" />
            <ServiceInstance name="f6cd1d7ef1644557b9059345e5ba890c.0" guid="{5f60b5ac-c18b-409d-898f-457e0c68e3b4}" />
          </Deployment>
          <Incarnation number="1" instance="lars-test-1" guid="{ae4f8ba1-08d5-4e6c-ae67-6dd36d7b2114}" />
          <Role guid="{bfb200dd-637f-6714-805b-18c16799a4cd}" name="lars-test-1" settleTimeSeconds="0" />
          <LoadBalancerSettings timeoutSeconds="0" waitLoadBalancerProbeCount="8">
            <Probes>
              <Probe name="D41D8CD98F00B204E9800998ECF8427E" />
              <Probe name="36F83AEC94AE1DFC70BFCFBDD173D1D6" />
            </Probes>
          </LoadBalancerSettings>
          <OutputEndpoints>
            <Endpoint name="lars-test-1:openInternalEndpoint" type="SFS">
              <Target instance="lars-test-1" endpoint="openInternalEndpoint" />
            </Endpoint>
          </OutputEndpoints>
          <Instances>
            <Instance id="lars-test-1" address="100.115.176.25">
              <FaultDomains randomId="0" updateId="0" updateCount="0" />
              <InputEndpoints>
                <Endpoint name="openInternalEndpoint" address="100.115.176.25" protocol="any" isPublic="false" enableDirectServerReturn="false" isDirectAddress="false" disableStealthMode="false">
                  <LocalPorts>
                    <LocalPortSelfManaged />
                  </LocalPorts>
                </Endpoint>
                <Endpoint name="ssh" address="100.115.176.25:22" protocol="tcp" hostName="lars-test-1ContractContract" isPublic="true" loadBalancedPublicAddress="40.76.213.32:22" enableDirectServerReturn="false" isDirectAddress="false" disableStealthMode="false">
                  <LocalPorts>
                    <LocalPortRange from="22" to="22" />
                  </LocalPorts>
                </Endpoint>
              </InputEndpoints>
            </Instance>
          </Instances>
        </SharedConfig>

- `/machine/<container_id>/<instance_id>?comp=config&type=extensionConfig&incarnation=1`

  A request looks like:

        curl -H "x-ms-version: 2012-11-30" -H "x-ms-agent-name: WALinuxAgent" 'http://100.115.176.3/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=config&type=extensionsConfig&incarnation=1'

  A response looks like:

        <?xml version="1.0" encoding="utf-8"?>
        <Extensions version="1.0.0.0" goalStateIncarnation="1"><GuestAgentExtension xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
          <GAFamilies>
            <GAFamily>
              <Name>Prod</Name>
              <Uris>
                <Uri>http://rdfepirv2bl2prdstr01.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl2prdstr02.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl2prdstr03.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl2prdstr04.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl3prdstr01.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl3prdstr02.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl3prdstr03.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl4prdstr01.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl4prdstr03.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl5prdstr02.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl5prdstr04.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl5prdstr06.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Prod_useast_manifest.xml</Uri>
              </Uris>
            </GAFamily>
            <GAFamily>
              <Name>Test</Name>
              <Uris>
                <Uri>http://rdfepirv2bl2prdstr01.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl2prdstr02.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl2prdstr03.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl2prdstr04.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl3prdstr01.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl3prdstr02.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://rdfepirv2bl3prdstr03.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl4prdstr01.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl4prdstr03.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl5prdstr02.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl5prdstr04.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
                <Uri>http://zrdfepirv2bl5prdstr06.blob.core.windows.net/7d89d439b79f4452950452399add2c90/Microsoft.OSTCLinuxAgent_Test_useast_manifest.xml</Uri>
              </Uris>
            </GAFamily>
          </GAFamilies>
          <Location>eastus</Location>
        </GuestAgentExtension>
        <StatusUploadBlob statusBlobType="BlockBlob">https://example.blob.core.windows.net/vm-images/lars-test-1.lars-test-1.lars-test-1.status?sr=b&amp;sp=rw&amp;se=9999-01-01&amp;sk=key1&amp;sv=2014-02-14&amp;sig=I3w8%2BrZg3Y2qDM5Qc48bk0qLDTEMR6Ez6Ufzx9SL5zg%3D</StatusUploadBlob></Extensions>


- `/machine/<container_id>/<instance_id>?comp=config&type=fullConfig&incarnation=1`

  This appears to be a combination of the other individual config endpoints.

- `/machine/<container_id>/<instance_id>?comp=certificates&incarnation=1`

  Requests certificates (such as SSH public keys) from the configuration server.  This requires the `x-ms-guest-agent-public-x509-cert` HTTP header, the value of which is an X509 certificate that will be used to encrypt data to the client, and the `x-ms-cipher-name` header, which on my systems is set to `DES_EDE3_CBC`.

  The `waagent` script generates the certificate like this:

      openssl req -x509 -nodes -subj /CN=LinuxTransport -days 32768 \
        -newkey rsa:2048 -keyout TransportPrivate.pem -out TransportCert.pem

  A request looks like this:

        curl -H "x-ms-version: 2012-11-30" -H "x-ms-agent-name: WALinuxAgent" 'http://100.115.176.3/machine/a511aa6d-29e7-4f53-8788-55655dfe848f/f6cd1d7ef1644557b9059345e5ba890c.lars%2Dtest%2D1?comp=certificates&incarnation=1' -H 'x-ms-cipher-name: DES_EDE3_CBC" -H "x-ms-guest-agent-public-x509-cert: MIIDBzCCAe+gAwIBAgIJAIWfUkZm9kO7MA0GCSqGSIb3DQEBCwUAMBkxFzAVBgNVBAMMDkxpbnV4VHJhbnNwb3J0MCAXDTE2MDQxNjA0MjAxMloYDzIxMDYwMTAzMDQyMDEyWjAZMRcwFQYDVQQDDA5MaW51eFRyYW5zcG9ydDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANVx7qUSBq6Xif73Eu6C70mfBZH1bif3IEUmmqTGL7kqD3Q+ENgmNCVegXO5Gx6QIjFzDV4vda8f5Eyyhw2dLJApJ4ghvm+dCTK60unMC7HZsHy9LulIvvkuPIb9iPxYAsXjhPe69ZtFeOeWabTIJScYjIk73at/F44KUtAHgIymHgkoxhzERDU8NufuvX8ATRW1D27ZLBnq0f+lgqu+FhYzNZQBKZ2EkGojEJb2GSZg0628SzDrQKCe5CEyDCOaRTIxDmjU5ou6AbH36WWxH4C1i62FaAoDMn7e0k5yGstqcZO+n2Zeh5oS7blKWK3GarnJcPbh/ulniUU+BtmERVMCAwEAAaNQME4wHQYDVR0OBBYEFEVAakbIzxxaMX1CQckBbQfXSVWIMB8GA1UdIwQYMBaAFEVAakbIzxxaMX1CQckBbQfXSVWIMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBACStjmZTm24ZFJ5klRUCysOj3kujMxY/84v5uMS+UrKEltjK5D7nVJV67T6qa/fDGsp0XYwA1gz2Zy9TrOHkn/23WwuKhPgrSQfoyxMkYkPLqP/Af1k2vWtFqQzuApdAi9YkT8lLoEGuVPJ8P9q0TUzgzv/X/AR4vMo3lgeLRV2PCsw5lCc3xBn3V+YcZOHdTYdN605JsfJLd8dxkSup2bWQJM20X/N6qsCePkg97bjF9n/IYMaOPrRkten/0qoVd20oZK097252tv0vCdx5J2V96MN/l/nnstqzrqSIQaeGWIQg7f/zgDvxg/tu9z0IeNzWKdvbu418tzMPM7QWQeI="

  A response looks like this:

        <?xml version="1.0" encoding="utf-8"?>
        <CertificateFile xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="certificates10.xsd">
          <Version>2012-11-30</Version>
          <Incarnation>1</Incarnation>
          <Format>Pkcs7BlobWithPfxContents</Format>
          <Data>MIIFHAYJKoZIhvcNAQcDoIIFDTCCBQkCAQIxggEwMIIBLAIBAoAURUBqRsjPHFox
        fUJByQFtB9dJVYgwDQYJKoZIhvcNAQEHMAAEggEABwuiRfBllUWpOw9H38/+sb7T
        pc8GpYmV78SHVV6mMg1PD9GukaHtAVvjdWEhaDQ1UsH7BIAMD5HyAwGsnvyJyoZC
        J0SZX31eNT6U6FRZesyB1GxyCeTQb09Gokm+hJgoILMC9UwEABWv5QVWaEolHEl7
        VnxLeAOQBfKN6lch6xuQKkwGUnk8M1cjFeIyXvlHw8T58xSo0nR+v22bbCmXaDkx
        Y2HD1i9titMJO7gJYtfFNIKDcLgTRAqQljX6M+fpDMYoKI29lbBeH6DzgfYWA0aD
        UPfidfy2GuBSnL5tLaEMASH6C11D/28aLRni+Gt+Pw0kNX5iKb5f0eugONiR3jCC
        A84GCSqGSIb3DQEHATAdBglghkgBZQMEAQIEEBW1AY9XvU2/vaFBulJHRniAggOg
        Y+SvY1YXbHk8mWC/lCI2+1dsFLJiRTdrR4QYs3njJd1MRfjl/gGeFVqr3a5ARL46
        YKwjo2Re7wHPA85VBngJk+FkGml+xYlZoZWLhxj4jlF+eUQX9HNTJIJ9xGKteQyR
        tzdw/kFESqyCduNY3npEN926YOV3sgvCjgcXbY5iprWyKxJV+uBwZklthFHQC463
        ubOsWYNhmYIwKx5StnxiyjgWohGqyQIWqtqFht4wmCMcbUdqqye/oZc5CjTm8cEw
        rd3MidN6224Skwd01eNMzRqGkJqZlX5dISFubMlUOmczfQQ4fkIcg7JJqicwFkjQ
        G17Bj5SL2sqhg4GUznEOjUkzRjA4mIV3HAVIg4ZfTKD7F5Gx/jYfRYmoNUrH6FQu
        sw96pFjUmTY0B1Wy+5T6EzYxP16utI+nvqGuxMkbV9fkBMstUSYTmrrVLe7j1u0w
        8Ig8jge11JqgsW11JQH75/xU1MkuBNCbEt/RgtEIcr4qS/Zsf9p0wMRTARPshe51
        ks7BCo5wSinnuUlgc7QzbEsXvHsGb7OqUFZ5geEsRhFW8QT08J9Boh3QrfgGESDI
        yjHWD+bYsX/lTOK1MXdkLa0/PhXZTvQyLtoMP6eHhZM/QEu/IV8Xc9nyS/9fsVoA
        3RasJShaSR+5eo3nx+lBYfYwvsXyExRIZuJVWM657gw8kELNRJT1tVwMBotIrE4t
        zJXcyzFWcapNHyiPMZhzILofdfaBOS6/2WAkNyxyUsJzxRhzOh75QuqRqF3lo3af
        /H6530CBeKJr3S6R441T1t6pD3jsAFAqFNJDI5rndtTC8N3+lSb3McKEgXqHYxIQ
        Wccdos4odNyTrJKzig8oFanAEqMhCAxDGzXnhpU46bFNhNnMHgL0BbCuzckg0tu5
        VdeVz2X8gJekHvv+8do2alSB2y8cFWdzulb0kEaKNfUSdjQOkTnXwMj32ym06off
        VmroVS1EzjKefIDTySTrjN6VdelJCbG72s3sdehQ/kllZW6cgWRM0zff9SwbY9Lq
        mOGcupob4NoTE3NkSFJ0lEwzHt56BnskfgbS9UqhU55ZsvZNjqOEzbjtt1HiuiqG
        kPwjVwYeW4I9crFEy4YP/fSx4bzk1IJuXyoI9DmoGDTd3ll7ynu+H5Bo+1c4tSsm
        Yl1YAxvscxKFpvpAsrt9M/8bpwSMauMaYf4NlR9ti+AkGDrmOtS0QIK5X5r5nYmy
        OxUvPh/AKpKKoc3tEbH/uw==
        </Data>
        </CertificateFile>

  The `waagent` script decrypts that response like this (using the key generated earlier when we created the certificate):

        openssl cms -decrypt -in Certificates.p7m -inkey TransportPrivate.pem \
          -recip TransportCert.pem |
        openssl pkcs12 -nodes -password pass: -out Certificates.pem

