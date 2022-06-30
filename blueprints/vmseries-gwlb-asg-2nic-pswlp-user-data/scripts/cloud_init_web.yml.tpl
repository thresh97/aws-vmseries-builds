#cloud-config

write_files:
  - path: /usr/local/share/ca-certificates/munge-ca.crt
    content: |
      -----BEGIN CERTIFICATE-----
      MIICxjCCAa6gAwIBAgIJAMnmM2+OH3YFMA0GCSqGSIb3DQEBCwUAMBMxETAPBgNV
      BAMTCE11bmdlIENBMB4XDTIxMTIxNTEyNDQzNloXDTIyMTIxNTEyNDQzNlowEzER
      MA8GA1UEAxMITXVuZ2UgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
      AQC5VmllZn5oCEmaEuuShLbn1HvjMENFCw+9vnvVcRiB6S6dNJAjEkCUcTgXlqY7
      bsSnjAIpbdDqQ6uMEToPvCbm5eaDAa5FX/b8dVAHdXfu9+LZ/PHpgzZqMqtKxzJ/
      xRn2l6WQqjUqFc5AFnaGxYL0d3VV9RohYj0TvDmSGGm4EIBPA5oCFzxtMsZ2DzAL
      zkJmw4CjPlBGyJlAr1PINDhthtDLfnXcZBn8HWyaEuQNucP8d9aR3Ao/MGr4sk/0
      0oap22TTvy6Y9WToqNSYmFFE31kQmreru9AXIz2ZP3Hqr8300IbTjdh/MR4jA0vq
      v4dBmscwJO/Lf30caeLNOg7bAgMBAAGjHTAbMAwGA1UdEwQFMAMBAf8wCwYDVR0P
      BAQDAgIEMA0GCSqGSIb3DQEBCwUAA4IBAQCRx/Xkf5QQZG55ki9H9/c82wqeO7dV
      wTkjghgRZ1Fho+Ov0A3Fb7VJhTKy9mIzY5affUDi9QDw8/Bgholh3yQsJ2VZjZx4
      9ZQet05WJCRLvwpFOW5vrrFfq7SiP1xLFEnvoABM0re4F3Qx0AbCI34zfuJOaCEX
      aWKocsBVJTQoSJl9+P0NFYo7915wva2K104dyiEuu0QCq2XHOjcHP/NhmsEZPZo1
      CdDNst2AX+SsQqsEzb90W3L4LMTpkjyIXNjKCv9VXrb6VQxPEp/aOQliVAoNkm7r
      UMIANKvbDfcNv+5f79PSmOMV4fVOS2291b7YeYpBu9e2ri3ye/vTTMSN
      -----END CERTIFICATE-----

runcmd:
  - sudo update-ca-certificates
  - sudo sleep 120
  - sudo apt-get update
  - until sudo apt-get install -y php; do echo "Retrying"; sleep 2; done
  - until sudo apt-get install -y apache2; do echo "Retrying"; sleep 2; done
  - until sudo apt-get install -y libapache2-mod-php; do echo "Retrying"; sleep 2; done
  - until sudo apt-get install -y iperf; do echo "Retrying"; sleep 2; done
  - until sudo rm -f /var/www/html/index.html; do echo "Retrying"; sleep 2; done
  - until sudo wget -O /var/www/html/index.php https://raw.githubusercontent.com/wwce/terraform/master/gcp/adv_peering_4fw_2spoke/scripts/showheaders.php; do echo "Retrying"; sleep 2; done
  - sudo systemctl restart apache2
