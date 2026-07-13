# Test Credentials & Testing Guide

> **Development use only.** These credentials are for the shared test account
> used during local development and CI. Do not use in production.

## Test Account

| Field    | Value        |
|----------|--------------|
| Phone    | 8178340031   |
| Password | Test@123     |

## Manual App Testing

1. Run the app locally:
   ```bash
   flutter run
   ```
2. On the phone entry screen, enter `8178340031`.
3. On the login screen, enter password `Test@123`.
4. If prompted for profile completion, fill in details or tap **Skip**.

## Maestro E2E Tests

The shared login flow (`.maestro/_shared/login.yaml`) reads credentials from
environment variables. Set them before running Maestro:

```bash
export TEST_PHONE="8178340031"
export TEST_PASSWORD="Test@123"
```

In CI, these are provided via GitHub Actions secrets (`TEST_PHONE` and
`TEST_PASSWORD`).

See [maestro.md](maestro.md) for full Maestro setup, prerequisites, and
troubleshooting.

### Quick run

```bash
# Smoke test
./scripts/run_maestro_smoke.sh ios

# Full E2E
./scripts/run_maestro_full.sh ios
```

## Unit & Widget Tests

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/core/data/models/property_model_test.dart

# Run with coverage
flutter test --coverage
```

No test credentials are needed for unit/widget tests -- they use inline
fixtures and mocks.
