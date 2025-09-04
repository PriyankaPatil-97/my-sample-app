pipeline {
  agent any

  environment {
    AWS_ACCOUNT_ID = "676206916950"
    AWS_REGION     = "ap-south-1"
    ECR_REPO       = "my-sample-app"
    IMAGE_NAME     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    IMAGE_TAG      = "${BUILD_NUMBER}"
  }

  tools { maven "Maven" }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build (package)') {
      steps {
        sh 'mvn -B -DskipTests clean package'
      }
    }

    stage('Unit Tests') {
      steps {
        sh 'mvn -B test'
        junit '**/target/surefire-reports/*.xml'
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          withSonarQubeEnv('SonarQube') {
            sh 'mvn -B sonar:sonar -Dsonar.login=$SONAR_TOKEN'
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          script {
            def qg = waitForQualityGate()
            echo "Quality gate status: ${qg.status}"
            if (qg.status != 'OK') {
              error "Quality Gate failed: ${qg.status}"
            }
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        script {
          sh """
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          """
        }
      }
    }

    stage('Trivy Scan (Image)') {
      steps {
        script {
          sh """
            trivy image --exit-code 0 --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
          """
        }
      }
    }

    stage('ECR Login & Push') {
      steps {
        script {
          sh """
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
          """
        }
      }
    }
  }
}
