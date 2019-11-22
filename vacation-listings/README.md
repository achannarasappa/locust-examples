# vacation listings

Example Locust web scraper to collect the latest Craigslist vacation home listings in New York City. Runs on Amazon Web Services and uses RDS, ElasticCache, and AWS Lambda.

## Cloud

### Setup

1. Setup [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
1. Install [terraform](https://www.terraform.io/downloads.html)

### Deploy

1. Zip source from project root
  ```sh
  npm run build
  ```
1. Deploy infrastructure and source
  ```sh
  terraform apply
  ```

### Invoke

```sh
aws lambda invoke \
--invocation-type Event \
--function-name vacation-listings \
--region us-east-1  \
--profile default \
out.txt
```

## Local

### Setup

1. Install [locust-cli](https://www.npmjs.com/package/@achannarasappa/locust-cli)
1. Install [Docker Compose](https://docs.docker.com/compose/install/)
1. Install [NodeJS](https://nodejs.org/en/download/package-manager/#nvm)

### Run

1. Start local dependencies
  ```sh
  docker-compose up
  ```
1. Start job via cli
  ```sh
  locust start src/job.js
  ```