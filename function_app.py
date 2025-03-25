import azure.functions as func
import logging
import json
import http.client
import urllib.parse
import os

# Load configuration from environment variables
RECORDINGS_CONTAINER = os.environ.get("RECORDINGS_CONTAINER", "raw")
API_VERSION = os.environ.get("API_VERSION", "2024-11-15")
STORAGE_ACCOUNT = os.environ.get("STORAGE_ACCOUNT")
SPEECH_SUBSCRIPTION_KEY = os.environ.get("SPEECH_SUBSCRIPTION_KEY")
ENDPOINT = os.environ.get("ENDPOINT", "https://.api.cognitive.microsoft.com/speechtotext/v3.2/transcriptions")
OUTPUT_CONTAINER = os.environ.get("OUTPUT_CONTAINER", "transcribed")
SAS = os.environ.get("SAS")

def run_transcription():
    # Validate required environment variables
    if not STORAGE_ACCOUNT:
        logging.error("STORAGE_ACCOUNT environment variable is not set")
        raise ValueError("STORAGE_ACCOUNT environment variable is required")
    if not SPEECH_SUBSCRIPTION_KEY:
        logging.error("SPEECH_SUBSCRIPTION_KEY environment variable is not set")
        raise ValueError("SPEECH_SUBSCRIPTION_KEY environment variable is required")
    if not SAS:
        logging.error("SAS environment variable is not set")
        raise ValueError("SAS environment variable is required")
        
    headers = {
        "Ocp-Apim-Subscription-Key": SPEECH_SUBSCRIPTION_KEY,
        "Content-Type": "application/json"
    }
    body = {
        "contentContainerUrl": f"https://{STORAGE_ACCOUNT}.blob.core.windows.net/{RECORDINGS_CONTAINER}",
        "locale": "en-CA",
        "displayName": f"Transcription of audio files in {RECORDINGS_CONTAINER}",
        "properties": {
            "diarizationEnabled": True,
            "destinationContainerUrl": f"https://{STORAGE_ACCOUNT}.blob.core.windows.net/{OUTPUT_CONTAINER}?{SAS}",
            "wordLevelTimestampsEnabled": True,
            "languageIdentification": {
                "candidateLocales": ["en-CA", "fr-CA"]
            }
        },
    }
    parsed_url = urllib.parse.urlparse(ENDPOINT)
    conn = http.client.HTTPSConnection(parsed_url.netloc)
    body_str = json.dumps(body)
    conn.request("POST", parsed_url.path, body_str, headers)
    response = conn.getresponse()
    result = json.loads(response.read().decode())
    conn.close()
    return result

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="text_to_speech")
def text_to_speech(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Processing HTTP trigger for text_to_speech.')

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