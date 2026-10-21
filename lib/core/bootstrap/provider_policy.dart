/// HTTP owns bounded retries. Provider initialization must never multiply them
/// or automatically replay a mutation after an ambiguous response.
Duration? noProviderRetry(int retryCount, Object error) => null;
