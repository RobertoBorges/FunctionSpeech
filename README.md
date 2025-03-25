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

RECORDINGS_CONTAINER = "recordings_audio_source"
API_VERSION = "2024-11-15"
STORAGE_ACCOUNT = "transcriptfunctionstorage"
SPEECH_SUBSCRIPTION_KEY = "YOUR_SPEECH_SUBSCRIPTION_KEY"
ENDPOINT = "https://REGION.api.cognitive.microsoft.com/speechtotext/v3.2/transcriptions"
OUTPUT_CONTAINER = "transcriptions_results"
SAS = "SAS_TOKEN FROM STORAGE ACCOUNT THAT WILL BE USED BY SPEECH SERVICE TO DROP RESULTS"
