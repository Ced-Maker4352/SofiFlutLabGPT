---
description: how to use local Ollama/Qwen if primary assistant is unavailable
---

# Emergency Fallback Workflow

If you hit a usage limit with your AI assistant or the Gemini API, follow these steps to keep working using your local machine.

## 1. Start Ollama

Ensure you have Ollama installed and running on your Mac.

- Open Terminal and run: `ollama run qwen2.5:7b` (or your preferred model)

## 2. Configure SophieGPT Settings

In the app's settings menu (⚙️):

1. Toggle "Use Custom AI Provider" -> **ON**.
2. Select "Generic AI (Ollama/Qwen/OpenAI)".
3. Set **Base URL** to: `http://localhost:11434/v1`
4. Set **Model Name** to: `qwen2.5:7b` (or your model name).

## 3. Continue Coding

You can now continue to generate images and content directly in your app using your local machine's GPU/CPU.

// turbo
4. Run `git add . && git commit -m "Switch to local Ollama fallback"` to track your progress.
