![swiggy_with_ssl](https://github.com/user-attachments/assets/d6dadf48-4634-4d98-8685-dc6722c78a74)

![swiggy_with_jenkins](https://github.com/user-attachments/assets/0470f07b-41cf-467c-982c-57d568e1da8e)



This project demonstrates how to build a complete CI/CD pipeline using:
- **Terraform** to provision EC2
- **Jenkins** for automation
- **SonarQube** for static analysis
- **Docker** for containerization
- **Trivy** for scanning
- **EKS (Elastic Kubernetes Service)** for deployment

---

## 🔧 Step 1: Provision EC2 Instance Using Terraform

```hcl
resource "aws_instance" "jenkins_server" {
  ami           = "ami-xxxxxxx"
  instance_type = "t3.large"
  key_name      = "your-key"
  tags = {
    Name = "Jenkins-Server"
  }
}
```

---

## ⚙️ Step 2: Install Jenkins, Docker and Trivy on EC2

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install -y jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## ⚙️ Install Docker
```
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io

echo "👤 Adding Jenkins user to Docker group..."
sudo usermod -aG docker jenkins
sudo usermod -aG docker $USER

echo "🔄 Restarting Docker..."
sudo systemctl enable docker
sudo systemctl restart docker
```
## ⚙️ Install Trivy
```
sudo apt install -y wget apt-transport-https gnupg lsb-release

wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
  https://aquasecurity.github.io/trivy-repo/deb \
  $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

sudo apt update -y
sudo apt install -y trivy
```
---

## 🐳 Step 3: Install SonarQube via Docker

```bash
docker run -d --name sonarqube -p 9000:9000 sonarqube:community
```

---

## 🔌 Step 4: Install Jenkins Plugins

Go to: `Manage Jenkins → Plugins → Available`, then install:

- Eclipse Temurin Installer
- SonarQube Scanner
- Sonar Quality Gates
- Quality Gate
- NodeJS
- All Docker-related plugins
- Stage View
- Pipeline
- Kubernetes CLI and Kubernetes Credentials

---

## 🧰 Step 5: Configure Jenkins Tools

Navigate to: `Manage Jenkins → Global Tool Configuration`

- **NodeJS**:  
  - Name: `node16`  
  - Version: `21.20` from nodejs.org

- **JDK**:  
  - Name: `jdk17`  
  - Install from Adoptium  
  - Version: `jdk-17.0.8.1+1`

- **Docker**:  
  - Name: `docker`  
  - Install from docker.com

- **SonarQube Scanner**:  
  - Name: `sonarqube-scanner`  
  - Install from Maven Central

---

## 🔒 Step 6: Configure SonarQube with Jenkins

1. Login to `http://<sonarqube-ip>:9000`  
   - Username: `admin`  
   - Password: `admin` (change it)

2. Create a token via:  
   `Administration → Security → Generate Token`

3. Add to Jenkins:  
   `Manage Jenkins → Credentials → Global → Add Credentials`  
   - **Kind**: Secret text  
   - **ID**: `SonarQube-Token`  
   - **Secret**: Paste token

4. Add SonarQube server:
   - Go to: `Manage Jenkins → Configure System`
   - Name: `SonarQube-Server`
   - URL: `http://<sonarqube-ip>:9000`
   - Token: `SonarQube-Token`

5. Create Quality Gate in SonarQube Dashboard

6. Add Webhook:  
   - Name: `jenkins`  
   - URL: `http://<jenkins-ip>:8080/sonarqube-webhook/`

---

## ☸️ Step 7: Install kubectl on EC2 (Master Machine)

```bash
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
kubectl version --short --client
```

---

## 📦 Step 8: Install AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip
unzip awscliv2.zip
sudo ./aws/install
aws configure
```

---

## 📥 Step 9: Install eksctl

```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
cd /tmp
sudo mv /tmp/eksctl /bin
eksctl version
```

---

## ☸️ Step 10: Create EKS Cluster

```bash
eksctl create cluster --name swiggy-clone --region eu-north-1 --node-type t3.medium --nodes 3
```

Check cluster status:

```bash
kubectl get nodes
kubectl get svc
```

> 📁 Copy your `~/.kube/config` to your **local Jenkins machine** for integration.

---

## 🔐 Step 11: Add Kubernetes Credentials to Jenkins

1. Go to `Manage Jenkins → Credentials → Global → Add Credentials`
   - Kind: `File`
   - Scope: Global
   - ID: `kubernetes`
   - Upload your `kube/config` file

---

## 🤖 Step 12: Jenkins Pipeline Script

> Save the following pipeline under a Jenkins item named `swiggy-cicd`

```groovy
pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node16'
    }

    environment {
        SCANNER_HOME = tool 'sonarqube-scanner'
        DOCKER_IMAGE = 'rohitjain064/swiggy-clone:latest'
    }

    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/helloworld064/swiggy-clone.git'
            }
        }
        
         stage("Sonarqube Analysis "){
             steps{
                 withSonarQubeEnv('SonarQube-Server') {
                     sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Swiggy-CI \
                     -Dsonar.projectKey=Swiggy-CI '''
                 }
             }
         }
         stage("Quality Gate"){
            steps {
                 script {
                     waitForQualityGate abortPipeline: false, credentialsId: 'SonarQube-Token' 
                 }
             } 
         }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs . > trivyfs.txt'
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockerhub', toolName: 'docker') {
                        sh 'docker build -t swiggy-clone .'
                        sh "docker tag swiggy-clone $DOCKER_IMAGE"
                        sh "docker push $DOCKER_IMAGE"
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "trivy image $DOCKER_IMAGE > trivyimage.txt"
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )]) {
                        withEnv(["AWS_REGION=eu-north-1"]) {
                            dir('Kubernetes') {
                                sh 'ls -la' // 🔍 Optional debug: show available files
                                withKubeConfig(credentialsId: 'kubernetes') {
                                    sh 'kubectl delete --all pods || true'
                                    sh 'kubectl apply -f deployment.yml'
                                    sh 'kubectl apply -f service.yml'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

```

> Save `deployment.yaml` and `service.yaml` under a folder called `Kubernetes` in your GitHub repo.

---

## ✅ Step 13: Setup GitHub Trigger

1. Go to Jenkins Pipeline > Configure
   - ✅ Check **GitHub project** → enter repo URL
   - ✅ Under **Build Triggers** → select `GitHub hook trigger for GITScm polling`

2. On GitHub:
   - Settings → Webhooks → Add webhook
   - Payload URL: `http://<jenkins-ip>:8080/github-webhook/`
   - Content type: `application/json`

3. Make a change in the repo to test the CI/CD pipeline trigger.

---

## ✅ Outcome

- Code gets pulled
- SonarQube scan runs
- Quality gate passes
- Docker image built and pushed to DockerHub
- Trivy scans performed
- Deployed to EKS via Jenkins pipeline

---

## 📎 Directory Structure

```bash
.
├── Kubernetes/
│   ├── deployment.yaml
│   └── service.yaml
├── README.md
```

---

----
## Cleanup
1--Delete EKS Cluster
```eksctl delete cluster --region=eu-south-1 --name=swiggy-clone```

2--Delete EC2 Instance with below Terraform Command
```terraform destroy```

----

## 📚 References

- [Jenkins Docs](https://www.jenkins.io/doc/)
- [SonarQube](https://www.sonarqube.org/)
- [Trivy](https://github.com/aquasecurity/trivy)
- [DockerHub](https://hub.docker.com/)
- [AWS EKS](https://docs.aws.amazon.com/eks/)
- [eksctl](https://eksctl.io/)




