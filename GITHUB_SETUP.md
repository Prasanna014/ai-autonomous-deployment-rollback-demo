# GitHub Setup Instructions

This document provides step-by-step instructions for creating and pushing the repository to GitHub.

## Prerequisites

1. GitHub account (https://github.com)
2. Git installed locally
3. GitHub CLI (optional but recommended) or use HTTPS/SSH authentication

## Method 1: Using GitHub CLI (Recommended)

### Step 1: Install GitHub CLI
```bash
# On Ubuntu/Debian
sudo apt-get install gh

# On macOS
brew install gh

# On Windows (using winget)
winget install GitHub.cli
```

### Step 2: Authenticate with GitHub
```bash
gh auth login
# Follow the prompts to authenticate
```

### Step 3: Create Repository
```bash
cd /path/to/ai-autonomous-deployment-rollback-demo
gh repo create ai-autonomous-deployment-rollback-demo \
  --source=. \
  --remote=origin \
  --push
```

### Step 4: Verify
```bash
git remote -v
# Should show: origin  https://github.com/yourusername/ai-autonomous-deployment-rollback-demo.git
```

## Method 2: Using GitHub Web Interface + Git CLI

### Step 1: Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `ai-autonomous-deployment-rollback-demo`
3. Description: "A lightweight Flask application for demonstrating autonomous deployment and automatic rollback scenarios"
4. Select visibility: **Public** (for demo purposes)
5. Do NOT initialize with README (we already have one)
6. Click "Create repository"

### Step 2: Connect Local Repository

After creating the repository on GitHub, you'll see instructions. Follow these:

```bash
# Navigate to your local repository
cd /path/to/ai-autonomous-deployment-rollback-demo

# Add the remote (replace USERNAME with your GitHub username)
git remote add origin https://github.com/USERNAME/ai-autonomous-deployment-rollback-demo.git

# Rename branch to main if needed
git branch -M main

# Push to GitHub
git push -u origin main
```

### Step 3: Enter Credentials

When prompted, enter:
- **Username**: Your GitHub username
- **Password**: Your GitHub personal access token (not your password)

To create a personal access token:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token"
3. Select scopes: `repo` (full control of private repositories)
4. Click "Generate token"
5. Copy the token and use it as password

## Method 3: Using SSH

### Step 1: Generate SSH Key (if not already done)
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Press Enter for default location
# Enter passphrase (optional)
```

### Step 2: Add SSH Key to GitHub
```bash
# Display the public key
cat ~/.ssh/id_ed25519.pub
```

1. Copy the output
2. Go to https://github.com/settings/ssh/new
3. Paste the key
4. Click "Add SSH key"

### Step 3: Create Repository
Follow "Method 2" Step 1 to create repository on GitHub

### Step 4: Connect Using SSH
```bash
cd /path/to/ai-autonomous-deployment-rollback-demo

# Add the remote using SSH
git remote add origin git@github.com:USERNAME/ai-autonomous-deployment-rollback-demo.git

# Rename branch to main if needed
git branch -M main

# Push to GitHub
git push -u origin main
```

## Verification

After pushing, verify the repository is on GitHub:

```bash
# Show remote URL
git remote -v

# Show branch tracking
git branch -vv

# View commit history
git log --oneline
```

Visit https://github.com/USERNAME/ai-autonomous-deployment-rollback-demo to see your repository!

## Add GitHub Topics

To make the repository more discoverable:

1. Go to your repository on GitHub
2. Click "Settings" (top right)
3. Scroll to "Topics" section
4. Add these topics:
   - `deployment`
   - `rollback`
   - `automation`
   - `demo`
   - `ai`
   - `flask`
   - `python`
   - `harness`

## Add CI/CD Integration (Optional)

### GitHub Actions Example

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: 3.9
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run health check
        run: |
          python app.py &
          sleep 2
          curl http://localhost:8080/health
```

## Troubleshooting

### "Permission denied (publickey)"
- Ensure SSH keys are set up correctly
- Or use HTTPS method with personal access token

### "Repository already exists"
- Use different name or delete existing repository first

### "fatal: Not a git repository"
- Ensure you're in the correct directory
- Run `git init` if needed

## Next Steps

1. Add collaborators: Settings → Collaborators
2. Set up branch protection: Settings → Branches
3. Enable GitHub Pages for documentation (optional)
4. Add issue templates: Create `.github/ISSUE_TEMPLATE/`
5. Add pull request templates: Create `.github/pull_request_template.md`

## Repository URL

Once created, your repository will be available at:
```
https://github.com/USERNAME/ai-autonomous-deployment-rollback-demo
```

Clone it with:
```bash
git clone https://github.com/USERNAME/ai-autonomous-deployment-rollback-demo.git
```
