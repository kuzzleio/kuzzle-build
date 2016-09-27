packer build -var 'host=localhost' -var 'path=/tmp/kuzzle' -var 'remote_user=root' -var 'access_key=<access_key>' -var 'secret_key=<secret_key>' kuzzle.json



  "builders": [
    {
      "type": "digitalocean",
      "api_token": "ca3f62f8eceae265d0c041b99926d4201dcc5fd10f37b52d9ff3cf35a11a8648",
      "snapshot_name": "kuzzle-{{timestamp}}",
      "region": "lon1",
      "size": "512mb",
      "image": "ubuntu-16-04-x64"
    }
  ]