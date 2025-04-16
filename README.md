# Transcript Function Speech to Text

This is a Python Azure Function that convert audio files from Azure Blob Storage to text using Azure Speech Service.

Then the results are sent to OpenAI for redaction and the redacted results are stored in Azure Blob Storage.

![Audio transcription/redact](docs/architecture.png)

## Prerequisites

- Python 3.11.9 or later
- Azure Functions Core Tools
- Azure CLI
- Azure Storage Account
- Azure Speech Service
- Azure Function App
- Azure Blob Storage

## Quick Start with Bicep Deployment

You can quickly deploy all required resources using the provided Bicep template in the `infra` folder:

1. Log in to Azure CLI:
   ```
   az login
   ```

2. Create a resource group if needed:
   ```
   az group create --name YourResourceGroupName --location westus2
   ```

3. Deploy the Bicep template:
   ```
   az deployment group create \
     --resource-group YourResourceGroupName \
     --template-file infra/azureFunction.bicep \
     --parameters functionAppName=YourFunctionAppName \
     --parameters recordingsStorageName=YourRecordingsStorageName \
     --parameters speechSubscriptionKey=YourSpeechSubscriptionKey \
     --parameters speechRegion=westus2 \
     --parameters saOutputSas=YourSasToken \
     --parameters openaiCompletionsEndpoint=YourOpenAIEndpoint \
     --parameters completionsSubscriptionKey=YourOpenAIKey \
     --parameters languageSubscriptionKey=YourLanguageKey \
     --parameters languageEndpoint=YourLanguageEndpoint \
     --parameters redactedStorageAccountName=YourRedactedStorageName
   ```

### Example Parameters

Here's an example of parameter values (replace with your actual values):

``` bash
functionAppName=speech-function-app
recordingsStorageName=speechrecordings2025
speechSubscriptionKey=12345abcdef6789ghijklmn0123456789
speechRegion=westus2
saOutputSas="?sv=2022-11-02&ss=b&srt=sco&sp=rwdlaciytfx&se=2025-12-31T23:59:59Z&st=2025-04-15T00:00:00Z&spr=https&sig=abcdefghijklmnopqrstuvwxyz"
openaiCompletionsEndpoint=https://myopenai.openai.azure.com/
completionsSubscriptionKey=98765abcdef1234ghijklmn9876543210
languageSubscriptionKey=abcdef1234567890ghijklmnopq987654
languageEndpoint=https://mylanguage.cognitiveservices.azure.com/
redactedStorageAccountName=redactedspeech2025
```

### Post-Deployment Steps

After deployment:

1. Create the required containers in your storage accounts:

   ``` bash
   az storage container create --name audio-recordings --account-name YourRecordingsStorageName
   az storage container create --name transcriptions --account-name YourRecordingsStorageName
   az storage container create --name redacted-transcriptions --account-name YourRedactedStorageName
   ```

2. Assign required permissions as outlined in the Permissions section

3. Deploy your function code:

   ``` bash
   func azure functionapp publish YourFunctionAppName
   ```

## Deployment Steps

Deploy the function to Azure Function, and configure the environment variables in the Azure Function App settings.

``` bash
RECORDINGS_STORAGE_ACCOUNT_NAME = "STORAGE ACCOUNT NAME WITHOUT .blob.core.windows.net"
RECORDINGS_CONTAINER = "BLOB CONTAINER NAME WHERE THE AUDIO FILES ARE"
TRANSCRIPTION_OUTPUT_CONTAINER = "BLOB CONTAINER NAME WHERE THE TRANSCRIPTIONS WILL BE DROPPED"
SPEECH_SUBSCRIPTION_KEY = "YOUR_SPEECH_SUBSCRIPTION_KEY REQUIRED FOR SPEECH SERVICE"
SPEECH_TO_TEXT_ENDPOINT = "https://REGION.api.cognitive.microsoft.com"
SA_OUTPUT_SAS = "SAS_TOKEN FROM STORAGE ACCOUNT THAT WILL BE USED BY SPEECH SERVICE TO DROP RESULTS AS CALLBACK"
OPENAI_COMPLETIONS_ENDPOINT = "https://YOUR_COMPLETIONS_SERVICE.cognitiveservices.azure.com"
COMPLETIONS_SUBSCRIPTION_KEY = "YOUR_COMPLETIONS_SUBSCRIPTION_KEY"
OPENAI_COMPLETIONS_MODEL = "gpt-35-turbo"
LANGUAGE_SUBSCRIPTION_KEY = "YOUR_LANGUAGE_SUBSCRIPTION_KEY"
LANGUAGE_ENDPOINT = "https://YOUR_LANGUAGE_SERVICE.cognitiveservices.azure.com"
OUTPUT_REDACTED_CONTAINER = "BLOB CONTAINER NAME WHERE THE REDACTED TRANSCRIPTIONS WILL BE DROPPED"
REDACTED_STORAGE_ACCOUNT_NAME = "REDACTED RESULTS STORAGE ACCOUNT NAME WITHOUT .blob.core.windows.net"" 
OUTPUT_REDACTED_CONTAINER = "BLOB CONTAINER NAME WHERE THE REDACTED JSON WILL BE DROPPED"
```

## Additional Environment Variables

The following environment variables are required for the Azure Function App to run properly using managed identity without connection strings on the storage accounts:

```text
AzureWebJobsStorage__accountName = "STORAGE ACCOUNT NAME WITHOUT .blob.core.windows.net"
AzureWebJobsStorage__credential = "managedidentity" #exactly as it is
IngestAccount__blobServiceUri = "https://YOUR_STORAGE_ACCOUNT_NAME.blob.core.windows.net" # This is the storage account used by the function itself, the name IngestAccount is the connection string name used in the code
SCM_DO_BUILD_DURING_DEPLOYMENT = "1" # This is required to run the function in Azure Function App
ENABLE_ORYX_BUILD = "true" # This is required to run the function in Azure Function App
FUNCTIONS_WORKER_RUNTIME = "python" # This is required to run the function in Azure Function App
BUILD_FLAGS = "UseExpressBuild"
```

## Permissions

The function needs to have the following permissions on the storage accounts:

- `Storage Blob Data Contributor` on the storage account used by the function itself (IngestAccount in the code)
- `Storage Blob Data Owner` on the storage account used by the function itself (IngestAccount in the code)
- `Cognitive Services OpenAI Contributor` on the OpenAI service used for redaction (Completions in the code)
- `Cognitive Services User` on the OpenAI service used for redaction (Completions in the code)
- `Cognitive Services OpenAI User` on the OpenAI service used for redaction (Completions in the code)

The Speech Service needs to have the following permissions on the storage account used by the function itself (IngestAccount in the code):

- `Storage Blob Data Contributor` on the storage account used by the function itself (IngestAccount in the code)
