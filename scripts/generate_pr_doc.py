import os
import google.generativeai as genai
from github import Github

def generate_pr_doc(github_token: str, gemini_key: str, repo_name: str, pr_number: int):
    # 1. Initialize Clients
    gh = Github(github_token)
    repo = gh.get_repo(repo_name)
    pr = repo.get_pull(pr_number)
    
    # 2. Fetch Context
    diff_files = []
    for file in pr.get_files():
        if not file.filename.endswith(('lock.json', '.svg', '.png')):
            diff_files.append(f"File: {file.filename}\n{file.patch}")
    
    diff_content = "\n".join(diff_files[:10]) # Limit to 10 files to avoid massive payloads
    
    # 3. Generate Doc via Gemini
    genai.configure(api_key=gemini_key)
    model = genai.GenerativeModel('gemini-1.5-pro')
    
    prompt = f"""
    You are a Staff Software Engineer conducting a thorough architectural review. 
    Analyze this Pull Request and generate a formal, internal Technical PR Document.
    
    PR Title: {pr.title}
    PR Body: {pr.body or "No description provided."}
    
    Diff:
    {diff_content}
    
    Structure the document EXACTLY as follows using Markdown:
    ## 🏗️ Architecture & Logic Changes
    *Explain the core technical changes made.*
    
    ## 🔒 Security & Compliance Impact
    *Did this introduce new dependencies, auth changes, or external API calls? If none, state "No visible security impact."*
    
    ## 🧪 QA Testing Instructions
    *Provide a bulleted list of instructions for how a QA engineer should test this specific PR.*
    
    ## 🔙 Rollback Plan
    *What should be done if this breaks in production? (e.g., "Standard git revert is safe" or "Requires database migration rollback")*
    
    Be extremely pragmatic and technical. Do not use marketing fluff.
    """
    
    response = model.generate_content(prompt)
    doc_content = response.text
    
    # 4. Post as PR Comment
    comment_body = f"### 🤖 AI-Generated Technical PR Document\n\n{doc_content}"
    pr.create_issue_comment(comment_body)
    print("Successfully posted PR Document comment.")

if __name__ == "__main__":
    github_token = os.environ.get("GITHUB_TOKEN", "")
    gemini_key = os.environ.get("GEMINI_API_KEY", "")
    repo_name = os.environ.get("GITHUB_REPOSITORY", "")
    pr_number = int(os.environ.get("PR_NUMBER", "0"))
    
    if github_token and gemini_key and repo_name and pr_number:
        generate_pr_doc(github_token, gemini_key, repo_name, pr_number)
    else:
        print("Missing required environment variables.")
