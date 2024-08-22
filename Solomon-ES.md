Solomon Elasticsearch (ES)
=======

Provide credentials
-----------
The following properties must be set properly in the corresponding .env file

>ELASTIC_USERNAME=_**elastic**_<br/>
>ELASTIC_PASSWORD=_**changeme**_

Setup
-----------


1. Encrypting communications between nodes in a cluster
    - Creation of certificates<br/>
        Trigger the creation of certificates, run:
        > make setup

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
        Update the correponding _**`docker-compose.ksd.yml`**_ files<br/>

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
        
        Note: The ${ENV} corresponds to the set ENV value defined in .env file
        ```

        <br/>
        Update as well the **elasticsearch** service<br/>

        
        ```console
        secrets:
            - source: elasticsearch.keystore<br/>
              target: /usr/share/elasticsearch/config/elasticsearch.keystore<br/>
            - source: elastic.ca<br/>
              target: /usr/share/elasticsearch/config/certs/ca.crt<br/>
            - source: elasticsearch.certificate<br/>
              target: /usr/share/elasticsearch/config/certs/elasticsearch.crt<br/>
            - source: elasticsearch.key<br/>
              target: /usr/share/elasticsearch/config/certs/elasticsearch.key<br/>
        ```
        <br/>
        And the **kibana** service as well

        ```console
        secrets:
            - source: elastic.ca
              target: /certs/ca.crt
            - source: kibana.certificate
              target: /certs/kibana.crt
            - source: kibana.key
              target: /certs/kibana.key
        ```

<br/>

2. Encrypting HTTP client communications
    - Creation of KeyStore containing the certificate to enable TLS on the HTTP layer
        - Spawn an elasticsearch container using the command:
            ```console
            docker run --rm --name es -p 19200:9200 -p 19300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:7.11.1
            ```
        
        - Attach to the container created:
            ```console
            docker exec -it es **/bin/bash**
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
        <br/>
        - Go to the directory below (or create if needed)
            > solomon-secrets > ** \$\{ENV\}** > http<br/>
            > Note: The ** \$\{ENV\}** corresponds to the set **ENV** value defined in .env file
        <br/>
        - Copy the created zip file to solomon-secrets > ** \$\{ENV\}** > http by running the command:
            > docker cp es:/usr/share/elasticsearch/elasticsearch-ssl-http.zip .
        <br/>
        - Unzip the file
            > unzip -qq elasticsearch-ssl-http.zip -d .
        <br/>
        - Apply necessary permissions
            > find . -type f -exec chmod 655 -- {} +

        - Created certificates will be generated under certs folder with the following file structure:

            >|- **ca**<br/>
            >|   |- ca.p12<br/>
            >|   |- README.txt<br/>
            >|<br/>
            >|- **elasticsearch**<br/>
            >|   |- http.p12<br/>
            >|   |- README.txt<br/>
            >|   |- sample-elasticsearch.yml<br/>
            >|<br/>
            >|- **kibana**<br/>
            >    |- elasticsearch-ca.pem<br/>
            >    |- README.txt<br/>
            >    |- sample-kibana.yml<br/>

            Note: Follow the instructions as specified in the README.txt (See the next point below)

    - Configure secrets
        >secrets:<br/>
        >  elasticsearch.http.keystore:<br/>
        >    file: ./solomon-secrets/ ${ENV}/http/elasticsearch/http.p12<br/>
        >  kibana.http.ca:<br/>
        >    file: ./solomon-secrets/ ${ENV}/http/kibana/elasticsearch-ca.pem<br/>

    - Update the elasticsearch service
        >secrets:<br/>
        >  - source: elasticsearch.http.keystore<br/>
        >    target: /usr/share/elasticsearch/config/certs/http.p12<br/>
        >  - source: kibana.http.ca<br/>
        >    target: /certs/elasticsearch-ca.pem<br/>

<br/>
Docker Compose Build
----
Just run the following commad:
><i>make build-solomon</i><br/>

This will trigger the creation of the following images
><br>
>1. ksd/es:${ElasticsearchVersion}- \$\{ENV\}<br/>
>Example: ksd/es:7.11.1-local
><br/>
><br/>
>2. ksd/kibana:${ElasticsearchVersion}- \$\{ENV\}<br/>
>Example: ksd/kibana:7.11.1-local
><br>
><br/>

<br/>
Docker Compose Up
-----
Just run the following commad:
><i>make elk-solomon</i><br/>
>**OR**</br>
><i>docker-compose -f docker-compose.solomon.yml -f docker-compose.nodes.solomon.yml -f docker-compose.data.solomon.yml up --no-deps -d --no-recreate kibana es0 es1 es2 es3 es4</i><br/>

The command above will put up the 5-node elasticsearch service including kibana
</br>
</br>
To leave out the elasticsearch data nodes (es3 and es4), run the command:

><i>docker-compose -f docker-compose.solomon.yml -f docker-compose.nodes.solomon.yml -f docker-compose.data.solomon.yml up --no-deps -d --no-recreate kibana es0 es1 es2</i><br/>

<br/>
To test the elasticsearch service, run the command:

>curl -fsSkL "$ELASTICSEARCH_SCHEME://$ELASTIC_USERNAME:$ELASTIC_PASSWORD@$host:9200/_cat/health?h=status"

Note: Change the variables accordingly

<br/>
To test the kibana service, run the command:

>curl -fsSkL "$KIBANA_SCHEME://$ELASTIC_USERNAME:$ELASTIC_PASSWORD@$host:5601/api/status" | grep -Eo '"overall"[^}]*' | grep -Eo '"state"[^,]*' | grep -Eo '"green"[^"]*' | sed -r 's/"//g'

Note: Change the variables accordingly



<br/>
Connecting the Solomon Backend application to Elastic Search Cluster
----
To connect a specific container to an already existing network, run:

> <i>docker network connect --alias [network alias] [network name] [container]</i><br/>
>Example:<br/>
><i>docker network connect --alias elastic_network elastic my_containiner</i>

To disconnect an existing container to a defined network, run:

><i>docker network disconnect [network name] [container]</i><br/>
> Example:<br/>
><i>docker network disconnect elastic my_container</i>

<br/>
Defining the elasticsearch configuration in **solomon-backend**
---
1. Copy the file 
    >**solomon-secrets > local > http > ca > ca.p12**

    To the directory in **solomon-web** project 
    >**src > main > resources > certs**

    Rename it using the format: **ca_[ENV].p12** (Example: **ca_local.p12**)

2. Define the elasticsearch configuration as below
    >es:<br/>
    >  connectionMode: ${ES_CONN_MODE}<br/>
    >  clusterName: docker-cluster<br/>
    >  server: ${ES_SERVER}<br/>
    >  port: ${ES_PORT}<br/>
    >  useSSL: ${ES_USE_SSL}<br/>
    >  username: ${ES_USERNAME}<br/>
    >  password: ${ES_PASSWORD}<br/>
    >  certRelPath: certs/ca_${app.env}.p12<br/>

    Notes:<br/>
    >**ES_CONN_MODE**: CA_CERTIFICATE<br/>
    >**ES_SERVER**: [Elasticsearch Server - Either domain or IP]<br/>
    >**ES_PORT**: [Elasticsearch Server Port]<br/>
    >**ES_USE_SSL**: true<br/>
    >**ES_USERNAME**: [Defined Elasticsearch Username]<br/>
    >**ES_PASSWORD**: [Defined Elasticsearch Password]<br/>