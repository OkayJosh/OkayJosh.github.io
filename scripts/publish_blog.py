import os
import json
import urllib.request
from typing import Optional, Dict, Any, List


class CrossPublisher:
    def __init__(
        self, devto_key: str, hashnode_key: str, medium_token: str, medium_user_id: str
    ):
        self.devto_key = devto_key
        self.hashnode_key = hashnode_key
        self.medium_token = medium_token
        self.medium_user_id = medium_user_id

    def extract_title_and_body(self, markdown_content: str) -> tuple[str, str]:
        lines = markdown_content.strip().split("\n")
        title = "Generated Blog Post"
        body = markdown_content

        # Simple extraction if title starts with #
        if lines and lines[0].startswith("# "):
            title = lines[0][2:].strip()
            body = "\n".join(lines[1:]).strip()

        return title, body

    def publish_to_devto(self, title: str, body: str) -> Optional[str]:
        if not self.devto_key:
            return None

        data = {
            "article": {
                "title": title,
                "body_markdown": body,
                "published": False,  # Keep as draft initially
                "tags": ["engineering", "architecture", "coding"],
            }
        }

        req = urllib.request.Request(
            "https://dev.to/api/articles",
            data=json.dumps(data).encode("utf-8"),
            headers={"Content-Type": "application/json", "api-key": self.devto_key},
        )
        try:
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode("utf-8"))
                return result.get("url")
        except Exception as e:
            print(f"Dev.to publish failed: {e}")
            return None

    def publish_to_hashnode(
        self, title: str, body: str, publication_id: str
    ) -> Optional[str]:
        if not self.hashnode_key or not publication_id:
            return None

        query = """
        mutation CreateDraft($input: CreateDraftInput!) {
            createDraft(input: $input) {
                draft {
                    id
                }
            }
        }
        """

        variables = {
            "input": {
                "title": title,
                "contentMarkdown": body,
                "publicationId": publication_id,
            }
        }

        req = urllib.request.Request(
            "https://gql.hashnode.com/",
            data=json.dumps({"query": query, "variables": variables}).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": self.hashnode_key,
            },
        )
        try:
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode("utf-8"))
                return "Hashnode Draft Created"
        except Exception as e:
            print(f"Hashnode publish failed: {e}")
            return None

    def publish_to_medium(self, title: str, body: str) -> Optional[str]:
        if not self.medium_token or not self.medium_user_id:
            return None

        data = {
            "title": title,
            "contentFormat": "markdown",
            "content": body,
            "publishStatus": "draft",
            "tags": ["software-engineering", "architecture", "code-review"],
        }

        req = urllib.request.Request(
            f"https://api.medium.com/v1/users/{self.medium_user_id}/posts",
            data=json.dumps(data).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.medium_token}",
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode("utf-8"))
                return result.get("data", {}).get("url")
        except Exception as e:
            print(f"Medium publish failed: {e}")
            return None

    def cross_publish(self, filepath: str, hashnode_pub_id: str) -> None:
        with open(filepath, "r") as f:
            content = f.read()

        title, body = self.extract_title_and_body(content)

        print("Publishing to Dev.to...")
        devto_url = self.publish_to_devto(title, body)
        print(f"Dev.to: {devto_url}")

        print("Publishing to Hashnode...")
        hashnode_res = self.publish_to_hashnode(title, body, hashnode_pub_id)
        print(f"Hashnode: {hashnode_res}")

        print("Publishing to Medium...")
        medium_url = self.publish_to_medium(title, body)
        print(f"Medium: {medium_url}")


if __name__ == "__main__":
    devto_key = os.environ.get("DEVTO_API_KEY", "")
    hashnode_key = os.environ.get("HASHNODE_API_KEY", "")
    medium_token = os.environ.get("MEDIUM_INTEGRATION_TOKEN", "")
    medium_user_id = os.environ.get("MEDIUM_USER_ID", "")
    hashnode_pub_id = os.environ.get("HASHNODE_PUBLICATION_ID", "")

    # Get the latest markdown file added in the commit
    # In a real GH Action, we'd pass the file path via arguments
    import sys

    if len(sys.argv) > 1:
        filepath = sys.argv[1]
        publisher = CrossPublisher(
            devto_key, hashnode_key, medium_token, medium_user_id
        )
        publisher.cross_publish(filepath, hashnode_pub_id)
    else:
        print("Please provide the path to the markdown file.")
