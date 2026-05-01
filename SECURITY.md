# Security

Talkie Cabinet is a local macOS app. Inference runs on the user's Mac through a
local MLX Python worker. The app does not need cloud credentials at runtime.

## Credentials

- Keep `.env` local. It is ignored by git and should never be committed.
- `HF_TOKEN` is optional for faster Hugging Face downloads.
- Apple notarization credentials must stay in Keychain via `notarytool` profiles
  or in local environment variables while packaging. Never hardcode them.
- Do not publish screenshots, logs, or release output that contain tokens,
  Apple account data, private repo names, or local cache paths.

## Model Download

The default setup script downloads the public MLX q4 model from Hugging Face.
If you point `TALKIE_MLX_MODEL` at a private model, keep any required token in
your shell environment only and do not share generated logs.

## App Distribution

Release DMGs should be Developer ID signed, notarized, and stapled before public
distribution. Local debug builds do not need notarization.

## Reporting

If you find a security issue, open a private advisory or contact the maintainer
out of band before publishing details.
