# CURSOR PROMPT: Implement CI/CD + Firebase + Terraform Infrastructure

You are implementing CI/CD and infrastructure for the Event Hub project.

We have two environments:
- DEV
- PROD

Branch strategy:
- dev branch → deploy to DEV
- main branch → deploy to PROD

========================================================
## 1. GitHub Actions CI/CD
========================================================

Create:
.github/workflows/deploy.yml

Requirements:

- Trigger on push to:
  - dev
  - main
- Build Flutter Web
- Deploy to Firebase Hosting
- Use separate Firebase projects:
  - aisaiah-events-dev
  - aisaiah-events-prod
- Use GitHub secrets:
  - FIREBASE_SERVICE_ACCOUNT_DEV
  - FIREBASE_SERVICE_ACCOUNT_PROD

Implementation:

- Use subosito/flutter-action@v2
- Use FirebaseExtended/action-hosting-deploy@v0
- Deploy only if branch matches environment

Ensure:
- No firebase use commands
- No local switching
- Branch determines projectId

========================================================
## 2. Firebase Configuration Files
========================================================

Create:
firebase.json
.firebaserc

.firebaserc must NOT store project IDs directly.
We will deploy using service accounts via GitHub Actions.

firebase.json should:

- Configure hosting
- Use "build/web" as public directory
- Enable single-page app rewrite:
  {
    "source": "**",
    "destination": "/index.html"
  }

Do NOT hardcode domains in config.

========================================================
## 3. Firebase Security Rules (Firestore)
========================================================

Create:
firestore.rules

Requirements:

- Public users:
  - Can read limited registrant data only via session check-in logic
- Only authenticated users:
  - Can access /admin/*
- Only ADMIN role:
  - Can modify schema
  - Can run imports
- Only STAFF or ADMIN:
  - Can perform check-in writes
- No public write access to registrants
- Session attendance requires:
  - registrant must exist
  - eventAttendance.checkedIn == true

Use structure:
events/{eventId}/...

Implement role check using:
request.auth.token.email
and lookup in:
events/{eventId}/admins/{email}

========================================================
## 4. Terraform Infrastructure
========================================================

Create infrastructure folder:

/infra
  /dev
  /prod
  main.tf
  variables.tf
  outputs.tf

Terraform must:

- Create Firebase project (optional if already exists)
- Enable:
  - Firestore
  - Firebase Hosting
- Configure Firestore location
- Create IAM bindings for service accounts
- Enable required APIs:
  - firebase.googleapis.com
  - firestore.googleapis.com
  - cloudfunctions.googleapis.com
  - cloudbuild.googleapis.com

Use provider:
hashicorp/google

Variables:
- project_id
- region
- billing_account

Create:
- Separate terraform.tfvars for dev and prod

========================================================
## 5. Environment Separation Rules
========================================================

Ensure:

- Dev and Prod NEVER share Firebase projects
- Dev and Prod have separate service accounts
- No config files mix project IDs
- No environment detection in Flutter app
- Domain-based event loading continues to work independently

========================================================
## 6. README Documentation
========================================================

Create:

docs/DEPLOYMENT.md

Must include:

- How CI/CD works
- How to add GitHub secrets
- How to initialize Terraform
- How to deploy infra:
  terraform init
  terraform plan
  terraform apply
- How to rotate service account keys
- How to rollback production

========================================================
## 7. Quality Requirements
========================================================

- Clean separation of concerns
- No hardcoded credentials
- No manual deployment steps
- Branch-based deployment only
- Infrastructure reproducible via Terraform
