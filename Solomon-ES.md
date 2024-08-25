Solomon Elasticsearch (ES)
=======

Provide credentials
-----------
The following properties must be set properly in the corresponding .env file

```console
ELASTIC_USERNAME=elastic
ELASTIC_PASSWORD=changeme
```

Setup
-----------
1. Encrypting communications between nodes in a cluster
    - Creation of certificates<br/>
        Trigger the creation of certificates, run:
        ```console
        make setup
        ```
        
        Created certificates will be generated under certs folder with the following file structure:
        ```console
        certs
        |---- ca
        |     |---- ca.crt
        |
        |---- elasticsearch
        |     |---- elasticsearch.crt
        |     |---- elasticsearch.key
        |
        |---- kibana
              |---- kibana.crt
              |---- kibana.key
        
        keystore
        |----- elasticsearch.keystore
        ```


        Copy the created **`certs`** and **`keystore`** directories under the directory<br/>
        > solomon-secrets/**\$\{ENV\}**/ssl<br/>
        > Note: The **\$\{ENV\}** corresponds to the set **ENV** value defined in .env file

        <br/>

    - Configure secrets 
        <br/>
        Update the correponding **`docker-compose.ksd.yml`** files<br/>

        ```console
        secrets:
          elasticsearch.keystore:
            file: ./solomon-secrets/${ENV}/ssl/keystore/elasticsearch.keystore
          elastic.ca:
            file: ./solomon-secrets/${ENV}/ssl/certs/ca/ca.crt
          elasticsearch.certificate:
            file: ./solomon-secrets/${ENV}/ssl/certs/elasticsearch/elasticsearch.crt
          elasticsearch.key:
            file: ./solomon-secrets/${ENV}/ssl/certs/elasticsearch/elasticsearch.key
          kibana.certificate:
            file: ./solomon-secrets/${ENV}/ssl/certs/kibana/kibana.crt
          kibana.key:
            file: ./solomon-secrets/${ENV}/ssl/certs/kibana/kibana.key
        ```
        > Note: The ${ENV} corresponds to the set ENV value defined in .env file

        \
        Update as well the **`elasticsearch`** service
        ```console
        secrets:
          - source: elasticsearch.keystore
            target: /usr/share/elasticsearch/config/elasticsearch.keystore
          - source: elastic.ca
            target: /usr/share/elasticsearch/config/certs/ca.crt
          - source: elasticsearch.certificate
            target: /usr/share/elasticsearch/config/certs/elasticsearch.crt
          - source: elasticsearch.key
            target: /usr/share/elasticsearch/config/certs/elasticsearch.key
        ```
        
        And the **`kibana`** service as well
        ```console
        secrets:
            - source: elastic.ca
              target: /certs/ca.crt
            - source: kibana.certificate
              target: /certs/kibana.crt
            - source: kibana.key
              target: /certs/kibana.key
        ```



2. Encrypting HTTP client communications
    - Creation of KeyStore containing the certificate to enable TLS on the HTTP layer
        - Spawn an elasticsearch container using the command:
            ```console
            docker run --rm --name es -p 19200:9200 -p 19300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:8.10.4
            ```
        
        - Attach to the container created:
            ```console
            docker exec -it es /bin/bash
            ```

        - Then trigger the creation of the http certificates (silent):
            ```console
            ./bin/elasticsearch-certutil http -s
            ```
        
        - Follow the following answer to the questions (see characters in **bold**)
            > Generate a CSR? [y/N] **N**
            <br/>
            > Use an existing CA? [y/N] **N**
            <br/>
            <br/>
            >Subject DN: CN=Elasticsearch HTTP CA<br/>
            >Validity: 5y<br/>
            >Key Size: 2048<br/>
            >Do you wish to change any of these options? [y/N] **N**
            <br/>
            <br/>
            >CA password:  [<ENTER> for none] **[Provide the password to the elasticsearch as defined in the corresponding .env file]**
            <br/>
            Repeat password to confirm: **[Repeat the password]**
            <br/>
            For how long should your certificate be valid? [5y] **[Just press enter]**
            <br/>
            Generate a certificate per node? [y/N] **N**
            <br/>
            <br/>
            >Enter all the hostnames that you need, one per line.
            >When you are done, press <ENTER> once more to move on to the next step.
            >**[Just press enter]**
            <br/>
            >Is this correct [Y/n] **Y**
            <br/>
            <br/>
            >Enter all the IP addresses that you need, one per line.
            >When you are done, press <ENTER> once more to move on to the next step.
            >**[Just press enter]**
            <br/>
            >Is this correct [Y/n] **Y**
            <br/>
            <br/>
            >Key Name: elasticsearch
            >Subject DN: CN=elasticsearch
            >Key Size: 2048
            >Do you wish to change any of these options? [y/N] **N**
            <br/>
            <br/>
            >Provide a password for the "http.p12" file:  [<ENTER> for none] **[Provide the password to the elasticsearch as defined in the corresponding .env file]**
            <br/>
            Repeat password to confirm: **[Repeat the password]**
            <br/>
            <br/>
            >What filename should be used for the output zip file? [/usr/share/elasticsearch/elasticsearch-ssl-http.zip] **[Just press enter]**
            <br/>
            <br/>
            >Zip file written to /usr/share/elasticsearch/elasticsearch-ssl-http.zip
        
        - Go to the directory below (or create if needed)
            > solomon-secrets/**\$\{ENV\}**/http<br/>
            > Note: The **\$\{ENV\}** corresponds to the set **ENV** value defined in .env file
        
        - Copy the created zip file to `solomon-secrets/${ENV}/http` by running the command:
            ```console
            docker cp es:/usr/share/elasticsearch/elasticsearch-ssl-http.zip .
            ```
        
        - Unzip the file
            ```console
            unzip -qq elasticsearch-ssl-http.zip -d .
            ```
        
        - Apply necessary permissions
            ```console
            find . -type f -exec chmod 655 -- {} +
            ```

        - Created certificates will be generated under certs folder with the following file structure:
            ```console
            |- ca
            |  |- ca.p12
            |  |- README.txt
            |
            |- elasticsearch
            |  |- http.p12
            |  |- README.txt
            |  |- sample-elasticsearch.yml
            |
            |- kibana
               |- elasticsearch-ca.pem
               |- README.txt
               |- sample-kibana.yml
            ```
            > Note: Follow the instructions as specified in the README.txt (See the next point below)

    - Configure secrets
        ```console
        secrets:
          elasticsearch.http.keystore:
            file: ./solomon-secrets/${ENV}/http/elasticsearch/http.p12
          kibana.http.ca:
            file: ./solomon-secrets/${ENV}/http/kibana/elasticsearch-ca.pem
        ```

    - Update the elasticsearch service
        ```console
        secrets:
          - source: elasticsearch.http.keystore
            target: /usr/share/elasticsearch/config/certs/http.p12
          - source: kibana.http.ca
            target: /certs/elasticsearch-ca.pem
        ```
        <br/>


Docker Compose Build
----
Just run the following commad:
```console
make ksd-build
```

This will trigger the creation of the following images
<br>
>ksd/es:${ElasticsearchVersion}-\$\{ENV\}<br/>
>Example: ksd/es:8.10.4-local
<br/>

>ksd/kibana:${ElasticsearchVersion}-\$\{ENV\}<br/>
>Example: ksd/kibana:8.10.4-local

<br/>

Docker Compose Up
-----
Just run the following commad:
```console
make ksd-elk
```
**OR**</br>
```console
docker-compose -f docker-compose.ksd.yml -f docker-compose.ksd.nodes.yml -f docker-compose.ksd.data.yml up --no-deps -d --no-recreate kibana es0 es1 es2 es3 es4
```
Note: The command above will put up the 5-node elasticsearch service including kibana

</br>

To leave out the elasticsearch data nodes (es3 and es4), run the command:
```console
docker-compose -f docker-compose.ksd.yml -f docker-compose.ksd.nodes.yml -f docker-compose.ksd.data.yml up --no-deps -d --no-recreate kibana es0 es1 es2
```

<br/>

To test the elasticsearch service, run the command:
```console
curl -fsSkL "${ELASTICSEARCH_SCHEME}://${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}@${host}:9200/_cat/health?h=status"
```
Note: Change the variables accordingly

<br/>

To test the kibana service, run the command:
```console
curl -fsSkL "${KIBANA_SCHEME}://${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}@${host}:5601/api/status" | grep -Eo '"overall"[^}]*' | grep -Eo '"state"[^,]*' | grep -Eo '"green"[^"]*' | sed -r 's/"//g'
```
Note: Change the variables accordingly

<br/>

Connecting the Solomon Backend application to Elastic Search Cluster
----
To connect a specific container to an already existing network, run:
```console
docker network connect --alias [network alias] [network name] [container]
Example: docker network connect --alias elastic_network elastic my_containiner
```

To disconnect an existing container to a defined network, run:
```console
docker network disconnect [network name] [container]
Example: docker network disconnect elastic my_container
```

<br/>

Defining the elasticsearch configuration in **solomon-backend**
---

1. Copy the file 
    >**solomon-secrets/local/http/ca/ca.p12**

    To the directory in **solomon-web** project 
    >**src/main/resources/certs**

    Rename it using the format: **ca_[ENV].p12** (Example: **ca_local.p12**)

2. Define the elasticsearch configuration as below
    ```console
    es:
      connectionMode: ${ES_CONN_MODE}
      clusterName: docker-cluster
      server: ${ES_SERVER}
      port: ${ES_PORT}
      useSSL: ${ES_USE_SSL}
      username: ${ES_USERNAME}
      password: ${ES_PASSWORD}
      certRelPath: certs/ca_${app.env}.p12

    Where variables are:

    ES_USE_SSL: true
    ES_CONN_MODE: CA_CERTIFICATE
    ES_SERVER: [Elasticsearch Server - Either domain or IP]
    ES_PORT: [Elasticsearch Server Port]
    ES_USERNAME: [Defined Elasticsearch Username]
    ES_PASSWORD: [Defined Elasticsearch Password]
    ```