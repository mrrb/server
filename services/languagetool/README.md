# LanguageTool

[https://languagetool.org/](https://languagetool.org/)

Self-hosted grammar, spelling and style checker API.

## Notes

* N-gram language models (better suggestions for confused words, missing/duplicated words) are not enabled. To enable them later, mount the n-gram data into the container and set `langtool_languageModel=/ngrams`.
* Java heap can be tuned with the `Java_Xms` / `Java_Xmx` environment entries.
