# Patron Service

## Purpose

This endpoint proxies requests to certain Sierra API paths, exposing the following endpoints:

* `GET /api/v0.1/patrons`: Get first 50 patrons, optionally matching barcode, username, email, or id.
* `GET /api/v0.1/patrons/{id}`: Get patron by id
* `POST /api/v0.1/patrons/validate`: Validates that barcode and pin are correct. (May be thought of as "authenticate".)
* `GET /docs/patron`: Gets swagger partial describing the three endpoints above. (i.e. https://platform.nypl.org/docs/patron )

See [Swagger](./swagger.json) for full [OAI 2.0](https://swagger.io/specification/v2/) specification.

## Running locally

```
rvm use
bundle install
```

To run a local server against Sierra Test:

```
sam local start-api --region us-east-1 --template sam.local.yml --profile nypl-digital-dev
```

To run a specific query, choose an event in `./events` and run, for example:

```
sam local invoke --region us-east-1 --template sam.local.yml --profile nypl-digital-dev --event events/patrons-by-barcode.json
```

## Contributing

This repo follows a [Development-QA-Master Git Workflow](https://github.com/NYPL/engineering-general/blob/a19c78b028148465139799f09732e7eb10115eef/standards/git-workflow.md#development-qa-master)

## Testing

```
bundle exec rspec -fd
```
