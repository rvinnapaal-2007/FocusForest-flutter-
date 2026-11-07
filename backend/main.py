
import os
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from groq import Groq, APIError

# Load the .env file located beside this main.py file.
BACKEND_DIR = Path(__file__).resolve().parent
ENV_FILE = BACKEND_DIR / ".env"
load_dotenv(dotenv_path=ENV_FILE, override=False)

app = FastAPI(
    title="Focus Forest AI Backend",
    version="1.0.0",
)

# Local development only. Add your actual frontend origin here
# if you use a different host or port.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://habitsynch.web.app",
        "https://habitsynch.firebaseapp.com",
    ],
    # any localhost / 127.0.0.1 port while developing
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=20000)
    system: Optional[str] = Field(
        default="You are Focus Forest's helpful AI study coach.",
        max_length=8000,
    )
    temperature: float = Field(default=0.4, ge=0, le=2)
    max_tokens: int = Field(default=1800, ge=1, le=8192)


@app.get("/")
def health():
    return {"status": "Focus Forest backend is running"}


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "api_key_configured": bool(os.getenv("GROQ_API_KEY", "").strip()),
    }


@app.post("/chat")
def chat(request: ChatRequest):
    api_key = os.getenv("GROQ_API_KEY", "").strip()

    if not api_key:
        raise HTTPException(
            status_code=500,
            detail=(
                "GROQ_API_KEY is not configured. "
                "Add it to backend/.env and restart the backend."
            ),
        )

    if not request.message.strip():
        raise HTTPException(
            status_code=400,
            detail="Message is empty.",
        )

    client = Groq(api_key=api_key)

    messages = []

    if request.system and request.system.strip():
        messages.append({
            "role": "system",
            "content": request.system,
        })

    messages.append({
        "role": "user",
        "content": request.message,
    })

    models = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
    ]

    for model in models:
        try:
            result = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=request.temperature,
                max_tokens=request.max_tokens + 700,
                reasoning_effort="low",
            )

            return {
                "reply": result.choices[0].message.content or "",
                "model": model,
            }

        except APIError as exc:
            status = getattr(exc, "status_code", None)

            # Invalid credentials should not be retried with another model.
            if status in (401, 403):
                print(f"Groq authentication error: HTTP {status}")
                raise HTTPException(
                    status_code=502,
                    detail=(
                        "Groq rejected the API key. Check your backend/.env "
                        "file and verify that the key is active."
                    ),
                )

            # Try the fallback model for other API errors.
            print(f"Groq request failed for {model}: {exc}")

    raise HTTPException(
        status_code=502,
        detail=(
            "Groq requests failed for both models. "
            "Check the backend terminal, model availability, "
            "rate limits, and your Groq account."
        ),
    )
