"""
LLM API Client with support for multiple providers.
"""

import os
import time
import json
from typing import Optional, Dict, Any, List
from pathlib import Path
import yaml

# Provider-specific imports (lazy loaded)
# openai, anthropic, google.generativeai


class LLMClient:
    """Unified interface for multiple LLM providers."""
    
    def __init__(self, config_path: str = "config/models.yaml"):
        self.config = self._load_config(config_path)
        self.clients = {}
        self._init_clients()
    
    def _load_config(self, path: str) -> Dict:
        with open(path, 'r') as f:
            return yaml.safe_load(f)
    
    def _init_clients(self):
        """Lazy initialization; actual client created per request."""
        pass
    
    def _get_client(self, provider: str, model_config: Dict):
        """Factory method for provider clients."""
        if provider == "openai":
            import openai
            client = openai.OpenAI(
                api_key=os.environ.get(model_config.get("api_key_env", "OPENAI_API_KEY"))
            )
            return client, model_config.get("model_id")
        
        elif provider == "anthropic":
            import anthropic
            client = anthropic.Anthropic(
                api_key=os.environ.get(model_config.get("api_key_env", "ANTHROPIC_API_KEY"))
            )
            return client, model_config.get("model_id")
        
        elif provider == "google":
            import google.generativeai as genai
            genai.configure(
                api_key=os.environ.get(model_config.get("api_key_env", "GOOGLE_API_KEY"))
            )
            return genai, model_config.get("model_id")
        
        elif provider == "openai_compatible":
            import openai
            client = openai.OpenAI(
                base_url=model_config["base_url"],
                api_key=os.environ.get(model_config.get("api_key_env", "EMPTY"))
            )
            return client, model_config.get("model_id")
        
        else:
            raise ValueError(f"Unknown provider: {provider}")
    
    def generate(self, 
                 model_name: str, 
                 prompt: str,
                 system_prompt: Optional[str] = None,
                 temperature: Optional[float] = None,
                 max_tokens: Optional[int] = None) -> Dict[str, Any]:
        """
        Generate completion from specified model.
        
        Returns:
            Dict with keys: 'response', 'model', 'usage', 'latency_ms'
        """
        # Find model config
        model_config = None
        for m in self.config["models"]:
            if m["name"] == model_name:
                model_config = m
                break
        
        if model_config is None:
            raise ValueError(f"Model '{model_name}' not found in config")
        
        provider = model_config["provider"]
        temp = temperature if temperature is not None else model_config.get("temperature", 0.1)
        tokens = max_tokens if max_tokens is not None else model_config.get("max_tokens", 4096)
        
        start_time = time.time()
        
        try:
            if provider == "openai" or provider == "openai_compatible":
                client, model_id = self._get_client(provider, model_config)
                
                messages = []
                if system_prompt:
                    messages.append({"role": "system", "content": system_prompt})
                messages.append({"role": "user", "content": prompt})
                
                response = client.chat.completions.create(
                    model=model_id,
                    messages=messages,
                    temperature=temp,
                    max_tokens=tokens
                )
                
                result = {
                    "response": response.choices[0].message.content,
                    "model": model_id,
                    "usage": {
                        "prompt_tokens": response.usage.prompt_tokens,
                        "completion_tokens": response.usage.completion_tokens,
                        "total_tokens": response.usage.total_tokens
                    },
                    "latency_ms": (time.time() - start_time) * 1000
                }
            
            elif provider == "anthropic":
                client, model_id = self._get_client(provider, model_config)
                
                response = client.messages.create(
                    model=model_id,
                    max_tokens=tokens,
                    temperature=temp,
                    system=system_prompt or "",
                    messages=[{"role": "user", "content": prompt}]
                )
                
                result = {
                    "response": response.content[0].text,
                    "model": model_id,
                    "usage": {
                        "input_tokens": response.usage.input_tokens,
                        "output_tokens": response.usage.output_tokens,
                        "total_tokens": response.usage.input_tokens + response.usage.output_tokens
                    },
                    "latency_ms": (time.time() - start_time) * 1000
                }
            
            elif provider == "google":
                client, model_id = self._get_client(provider, model_config)
                model = client.GenerativeModel(model_id)
                
                full_prompt = prompt
                if system_prompt:
                    full_prompt = f"{system_prompt}\n\n{prompt}"
                
                response = model.generate_content(full_prompt)
                
                result = {
                    "response": response.text,
                    "model": model_id,
                    "usage": {
                        "total_tokens": response.usage_metadata.total_token_count
                    },
                    "latency_ms": (time.time() - start_time) * 1000
                }
            
            else:
                raise ValueError(f"Unsupported provider: {provider}")
            
            return result
        
        except Exception as e:
            return {
                "response": None,
                "error": str(e),
                "model": model_name,
                "latency_ms": (time.time() - start_time) * 1000
            }
    
    def get_available_models(self) -> List[str]:
        """Return list of configured model names."""
        return [m["name"] for m in self.config["models"] if m["provider"] != "offline"]


class OfflineClient:
    """Read pre-generated responses from disk for offline evaluation."""
    
    def __init__(self, input_dir: str):
        self.input_dir = Path(input_dir)
    
    def generate(self, model_name: str, prompt: str, **kwargs) -> Dict[str, Any]:
        """
        Look up pre-generated response by prompt hash.
        
        Expects files named: {prompt_hash}.txt or {prompt_hash}.json
        """
        import hashlib
        prompt_hash = hashlib.md5(prompt.encode()).hexdigest()[:16]
        
        response_file = self.input_dir / f"{prompt_hash}.txt"
        meta_file = self.input_dir / f"{prompt_hash}.json"
        
        if response_file.exists():
            response = response_file.read_text()
            metadata = {}
            if meta_file.exists():
                metadata = json.loads(meta_file.read_text())
            
            return {
                "response": response,
                "model": "offline",
                "usage": metadata.get("usage", {}),
                "latency_ms": metadata.get("latency_ms", 0)
            }
        else:
            return {
                "response": None,
                "error": f"No pre-generated response for hash {prompt_hash}",
                "model": "offline"
            }