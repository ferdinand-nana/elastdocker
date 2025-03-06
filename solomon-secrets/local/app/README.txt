There are two files in this directory:

1. This README file
2. ca.p12

## ca.p12

The "ca.p12" file is a PKCS#12 format keystore.
It contains a copy of the certificate and private key for your Certificate Authority.

You should keep this file secure, and should not provide it to anyone else.

The sole purpose for this keystore is to generate new certificates if you add additional nodes to your Elasticsearch cluster, or need to
update the server names (hostnames or IP addresses) of your nodes.

This keystore is not required in order to operate any Elastic product or client.
We recommended that you keep the file somewhere safe, and do not deploy it to your production servers.

Your keystore is protected by a password.
Your password has not been stored anywhere - it is your responsibility to keep it safe.


If you wish to create additional certificates for the nodes in your cluster you can provide this keystore to the "elasticsearch-certutil"
utility as shown in the example below:

    elasticsearch-certutil cert --ca ca.p12 --dns "hostname.of.your.node" --pass

See the elasticsearch-certutil documentation for additional options.
