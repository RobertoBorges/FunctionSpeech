import azure.functions as func
import logging
import json
import http.client
import urllib.parse
import os
from azure.storage.blob import BlobServiceClient, ContentSettings
from azure.identity import DefaultAzureCredential

# Load configuration from environment variables
RECORDINGS_CONTAINER = os.environ.get("RECORDINGS_CONTAINER", "raw")
STORAGE_ACCOUNT_NAME = os.environ.get("STORAGE_ACCOUNT_NAME")
SPEECH_SUBSCRIPTION_KEY = os.environ.get("SPEECH_SUBSCRIPTION_KEY")
SPEECH_TO_TEXT_ENDPOINT = os.environ.get("SPEECH_TO_TEXT_ENDPOINT", "https://.api.cognitive.microsoft.com/speechtotext/v3.2/transcriptions")
TRANSCRIPTION_OUTPUT_CONTAINER = os.environ.get("TRANSCRIPTION_OUTPUT_CONTAINER", "transcribed")
SA_OUTPUT_SAS = os.environ.get("SA_OUTPUT_SAS")
OPENAI_COMPLETIONS_ENDPOINT = os.environ.get("OPENAI_COMPLETIONS_ENDPOINT", "")
COMPLETIONS_SUBSCRIPTION_KEY = os.environ.get("COMPLETIONS_SUBSCRIPTION_KEY", "")
LANGUAGE_SUBSCRIPTION_KEY = os.environ.get("LANGUAGE_SUBSCRIPTION_KEY")
LANGUAGE_ENDPOINT = os.environ.get("LANGUAGE_ENDPOINT", "")
OUTPUT_REDACTED_CONTAINER = os.environ.get("OUTPUT_REDACTED_CONTAINER", "redacted")
REDACTED_STORAGE_ACCOUNT_NAME = os.environ.get("REDACTED_STORAGE_ACCOUNT_NAME")

def run_transcription():
    # Validate required environment variables
    if not STORAGE_ACCOUNT_NAME:
        logging.error("STORAGE_ACCOUNT_NAME environment variable is not set")
        raise ValueError("STORAGE_ACCOUNT_NAME environment variable is required")
    if not SPEECH_SUBSCRIPTION_KEY:
        logging.error("SPEECH_SUBSCRIPTION_KEY environment variable is not set")
        raise ValueError("SPEECH_SUBSCRIPTION_KEY environment variable is required")
    if not SA_OUTPUT_SAS:
        logging.error("SA_OUTPUT_SAS environment variable is not set")
        raise ValueError("SA_OUTPUT_SAS environment variable is required")
        
    headers = {
        "Ocp-Apim-Subscription-Key": SPEECH_SUBSCRIPTION_KEY,
        "Content-Type": "application/json"
    }
    body = {
        "contentContainerUrl": f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net/{RECORDINGS_CONTAINER}",
        "locale": "en-CA",
        "displayName": f"Transcription of audio files in {RECORDINGS_CONTAINER}",
        "properties": {
            "diarizationEnabled": True,
            "destinationContainerUrl": f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net/{TRANSCRIPTION_OUTPUT_CONTAINER}?{SA_OUTPUT_SAS}",
            "wordLevelTimestampsEnabled": True,
            "languageIdentification": {
                "candidateLocales": ["en-CA", "fr-CA"]
            }
        },
    }
    parsed_url = urllib.parse.urlparse(SPEECH_TO_TEXT_ENDPOINT)
    conn = http.client.HTTPSConnection(parsed_url.netloc)
    body_str = json.dumps(body)
    conn.request("POST", parsed_url.path, body_str, headers)
    response = conn.getresponse()
    result = json.loads(response.read().decode())
    conn.close()
    return result

# Create a single credential object to be reused
credential = DefaultAzureCredential()

def agent_detection(text):
    body = {
        "messages": [
            {
                "role": "user",
                "content": 'Based on the json text, which speaker is the call centre agent? Output should be simple json "{"speaker":number}". Text:' + text
            }
        ]
    }
    
    # Get token for Azure OpenAI
    token = credential.get_token("https://cognitiveservices.azure.com/.default").token
    
    # Build the URL for the OpenAI endpoint
    base_url = f"{OPENAI_COMPLETIONS_ENDPOINT}/openai/deployments/o3-mini/chat/completions?api-version=2025-01-01-preview"
    headers = {
        "Content-Type": "application/json", 
        "api-key": COMPLETIONS_SUBSCRIPTION_KEY
    }
    
    parsed_url = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed_url.netloc)
    body_str = json.dumps(body)
    conn.request("POST", parsed_url.path + "?" + parsed_url.query, body_str, headers)
    response = conn.getresponse()
    result = json.loads(response.read().decode())
    conn.close()
    
    return result["choices"][0]["message"]["content"]

def redact_text(text):
    body = {
        "kind": "PiiEntityRecognition",
        "parameters": {
            "modelVersion": "latest"
        },
        "analysisInput": {
            "documents": [
                {
                    "id": "1",
                    "language": "en",
                    "text": text
                }
            ]
        }
    }
    
    # Some Ai Services don't support managed identity, so we need to use the subscription key for these services.
    # https://learn.microsoft.com/en-us/azure/ai-services/authentication#:~:text=Authenticate%20with%20an,to%20speech%20API
    
    # Build the URL for the Language service endpoint
    pii_base_url = f"{LANGUAGE_ENDPOINT}/language/:analyze-text?api-version=2023-04-01"
    pii_headers = {
        "Content-Type": "application/json", 
        "Ocp-Apim-Subscription-Key": LANGUAGE_SUBSCRIPTION_KEY
    }
    
    parsed_url = urllib.parse.urlparse(pii_base_url)
    conn = http.client.HTTPSConnection(parsed_url.netloc)
    body_str = json.dumps(body)
    conn.request("POST", parsed_url.path + "?" + parsed_url.query, body_str, pii_headers)
    response = conn.getresponse()
    result = json.loads(response.read().decode())
    conn.close()
    
    return result

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="Voice_To_Text_To_Speech")
def Voice_To_Text_To_Speech(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Processing HTTP trigger for Voice_To_Text_To_Speech.')

    transcription_result = run_transcription()

    # Safely extract 'self' and 'links' with default values
    self_val = transcription_result.get("self", "N/A")
    links_val = transcription_result.get("links", "N/A")
    
    if self_val == "N/A" or links_val == "N/A":
        logging.warning("Missing one or more expected properties: 'self' or 'links' not found in transcription result.")

    logging.info(f"self: {self_val}")
    logging.info(f"links: {links_val}")

    response_body = (
        "Transcription request processed successfully.\n"
        f"self: {self_val}\n"
        f"links: {links_val}"
    )
    return func.HttpResponse(
        response_body,
        status_code=200
    )

@app.blob_trigger(arg_name="myblob", path="transcribed",
                               connection="IngestAccount") 
def Redact_Transcription(myblob: func.InputStream):
    logging.info(f"Python blob trigger function processed blob "
                 f"Name: {myblob.name} "
                 f"Blob Size: {myblob.length} bytes")
    
    # Skip processing if the blob is a report file
    if myblob.name.endswith("_report.json"):
        logging.info(f"Skipping report file: {myblob.name}")
        return
    
    blob_content = json.loads(myblob.read())
    
    output = []
    for phase in blob_content['recognizedPhrases']:
        start = phase['offset']
        end = phase['duration']
        speaker = str(phase['speaker'])
        text = phase['nBest'][0]['itn']
        redacted_text = redact_text(text)['results']['documents'][0]['redactedText']
        each = output.append({
            'Start_in_seconds': start,
            'End_in_seconds': end,
            'Text':  f"Speaker {speaker}: " + text,
            'Redacted_Text': f"Speaker {speaker}: " + redacted_text
        })

    output = {
        'agent': json.loads(agent_detection(str(output)[:1000]))['speaker'],
        'transcription': output
    }

    # Convert output to JSON string
    output_json = json.dumps(output)
    
    # Create a connection to the Azure Storage account using managed identity
    blob_service_client = BlobServiceClient(
        account_url=f"https://{REDACTED_STORAGE_ACCOUNT_NAME}.blob.core.windows.net",
        credential=credential
    )
    
    # Get a reference to the output container
    container_client = blob_service_client.get_container_client(OUTPUT_REDACTED_CONTAINER)
    
    # Preserve the folder structure from the source path
    # The blob trigger returns the path including the container name (e.g., "transcribed/folder1/file.json")
    # We need to extract the relative path without the container name
    input_blob_path = myblob.name
    # Remove the container name and leading slash if present
    relative_path = "/".join(input_blob_path.split("/")[1:]) if "/" in input_blob_path else input_blob_path
    
    # Create output blob name preserving folder structure but changing extension to _processed.json
    filename = os.path.basename(relative_path)
    directory = os.path.dirname(relative_path)
    output_blob_name = os.path.join(directory, os.path.splitext(filename)[0] + "_processed.json")
    
    # Upload the JSON data to blob storage
    blob_client = container_client.get_blob_client(output_blob_name)
    blob_client.upload_blob(
        output_json, 
        overwrite=True,
        content_settings=ContentSettings(content_type="application/json")
    )
    
    logging.info(f"Output JSON saved to blob storage: {OUTPUT_REDACTED_CONTAINER}/{output_blob_name}")
