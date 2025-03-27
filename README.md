# Transcript Function Speech to Text

This is a Python Azure Function that convert audio files from Azure Blob Storage to text using Azure Speech Service.

## Prerequisites

- Python 3.11.9 or later
- Azure Functions Core Tools
- Azure CLI
- Azure Storage Account
- Azure Speech Service
- Azure Function App
- Azure Blob Storage

## Deployment Steps

Deploy the function to Azure Function, and configure the environment variables in the Azure Function App settings.

STORAGE_ACCOUNT_NAME = "STORAGE ACCOUNT NAME WITHOUT .blob.core.windows.net"
RECORDINGS_CONTAINER = "BLOB CONTAINER NAME WHERE THE AUDIO FILES ARE"
TRANSCRIPTION_OUTPUT_CONTAINER = "BLOB CONTAINER NAME WHERE THE TRANSCRIPTIONS WILL BE DROPPED"
SPEECH_SUBSCRIPTION_KEY = "YOUR_SPEECH_SUBSCRIPTION_KEY REQUIRED FOR SPEECH SERVICE"
SPEECH_TO_TEXT_ENDPOINT = "https://REGION.api.cognitive.microsoft.com/speechtotext/v3.2/transcriptions"
SA_OUTPUT_SAS = "SAS_TOKEN FROM STORAGE ACCOUNT THAT WILL BE USED BY SPEECH SERVICE TO DROP RESULTS AS CALLBACK"
OPENAI_COMPLETIONS_ENDPOINT = "https://YOUR_COMPLETIONS_SERVICE.cognitiveservices.azure.com"
COMPLETIONS_SUBSCRIPTION_KEY = "YOUR_COMPLETIONS_SUBSCRIPTION_KEY"
LANGUAGE_SUBSCRIPTION_KEY = "YOUR_LANGUAGE_SUBSCRIPTION_KEY"
LANGUAGE_ENDPOINT = "https://YOUR_LANGUAGE_SERVICE.cognitiveservices.azure.com"
OUTPUT_REDACTED_CONTAINER = "BLOB CONTAINER NAME WHERE THE REDACTED TRANSCRIPTIONS WILL BE DROPPED"
