# Graph...

```console
$ kubectl create secret generic twitter-credentials \
  --from-literal=access-token=... --from-literal=access-token-secret=... \
  --from-literal=consumer-key=... --from-literal=consumer-secret=...
$ kubectl create secret generic azure-blob-credentials \
  --from-literal=account-name=... --from-literal=account-key=... \
  --from-literal=container-name=...
```

## License

[MIT](LICENSE)
