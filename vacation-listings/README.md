# vacation listings

Example Locust web scraper to collect the latest Craigslist vacation home listings in New York City. Runs on Amazon Web Services and uses RDS, ElasticCache, and AWS Lambda

## Cloud

### Setup

1. [terraform](https://www.terraform.io/downloads.html)
1. 

### Deploy

1. Zip source from project root
  ```
  npm run build
  ```
1. Deploy infrastructure and source
  ```
  terraform apply
  ```

### Invoke

```
aws lambda invoke \
--invocation-type Event \
--function-name vacation-listings \
--region us-east-1  \
--profile default \
out.txt
```

## Local

1. [Docker Compose](https://docs.docker.com/compose/install/)
1. [NodeJS](https://nodejs.org/en/download/package-manager/#nvm)
