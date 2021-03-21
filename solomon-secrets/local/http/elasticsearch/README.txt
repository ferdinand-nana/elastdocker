There are three files in this directory:

1. This README file
2. http.p12
3. sample-elasticsearch.yml

## http.p12

The "http.p12" file is a PKCS#12 format keystore.
It contains a copy of your certificate and the associated private key.
You should keep this file secure, and should not provide it to anyone else.

You will need to copy this file to your elasticsearch configuration directory.

Your keystore is protected by a password.
Your password has not been stored anywhere - it is your responsibility to keep it safe.

When you configure elasticsearch to enable SSL (but not before then), you will need to provide the keystore's password as a secure
configuration setting in Elasticsearch so that it can access your private key.

The command for this is:

   elasticsearch-keystore add "xpack.security.http.ssl.keystore.secure_password"


## sample-elasticsearch.yml

This is a sample configuration for Elasticsearch to enable SSL on the http interface.
You can use this sample to update the "elasticsearch.yml" configuration file in your config directory.
The location of this directory can vary depending on how you installed Elasticsearch, but based on your system it appears that your config
directory is /usr/share/elasticsearch/config

This sample configuration assumes that you have copied your http.p12 file directly into the config directory without renaming it.
