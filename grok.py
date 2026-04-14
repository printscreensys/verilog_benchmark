# Please install OpenAI SDK first: `pip3 install openai`
from dotenv import load_dotenv
from openai import OpenAI
import os

from eval.common import resolve_task_dir

client = OpenAI(
    api_key=os.environ.get("GROQ_API_KEY"),
    base_url="https://api.groq.com/openai/v1",
)

task_dir = resolve_task_dir("task_01")

with open(os.path.join(task_dir, "input.txt"), encoding="utf-8") as f:
    response = client.responses.create(
        input=f.read(),
        model="groq/compound",
    )

file_path = "tmp/output.v"
os.makedirs(os.path.dirname(file_path), exist_ok=True)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(response.output_text)
