/// Hard-coded Gemma model filename.
const gemmaModelFilename = 'gemma-4-E2B-it.litertlm';

/// Public model URL used for cloneable open-source builds.
const gemmaModelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

/// Expected model size from the accepted implementation plan.
const gemmaExpectedBytes = 2590000000;

/// Accepted byte-size tolerance.
const gemmaSizeToleranceBytes = 5000000;

/// Validates a byte size using the accepted tolerance.
bool isValidGemmaModelSize(int size) {
  return (size - gemmaExpectedBytes).abs() <= gemmaSizeToleranceBytes;
}
