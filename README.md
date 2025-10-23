# AWS EKS IRSA Least-Privilege Demonstration

## 💡 Overview

This repository provides the configuration files and step-by-step instructions to implement **IAM Roles for Service Accounts (IRSA)** on an Amazon Elastic Kubernetes Service (EKS) cluster. The primary goal is to enforce the **Principle of Least Privilege** by granting a Kubernetes application Pod access to a single, specific AWS resource (e.g., an S3 bucket) **without** giving the user or the node any unnecessary cluster-wide permissions.

This document also serves as a professional record of resolving the common "Forbidden" RBAC access issue encountered during the initial configuration of EKS Access Entries.

---

## 🚀 Prerequisites

To successfully execute this demonstration, the following resources and tools must be accessible and configured:

1.  **AWS Account & Credentials:** AWS CLI configured with a profile possessing the necessary IAM permissions to manage EKS and IAM resources.
2.  **EKS Cluster:** A running EKS cluster named `irsa-least-privilege-demo`.
3.  **kubectl:** Configured locally and successfully authenticated to the target EKS cluster.
4.  **OIDC Provider:** The EKS cluster must have its IAM OpenID Connect (OIDC) Identity Provider associated. (Verified: `https://oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>`).
5.  **Application Image:** An accessible Docker image (e.g., `my-registry/my-app-image:latest`) that can run shell commands for verification.

---

## ⚙️ Deployment Steps

The solution is implemented across three logical phases: resolving initial access, configuring the least-privilege role, and deploying the IRSA-enabled application.

### Phase 1: Resolving Initial Administrative Access

This step grants the demo user administrative permissions necessary to manage subsequent RBAC resources.

1.  **Associate EKS Cluster Admin Policy:** Utilizes the AWS EKS API to grant admin access to the demo principal.

    ```bash
    aws eks associate-access-policy \
        --cluster-name irsa-least-privilege-demo \
        --principal-arn arn:aws:iam::<AWS_ACCOUNT_ID>:user/DemoUser \
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
        --access-scope type=cluster
    ```

2.  **Verify Administrative Access:**

    ```bash
    kubectl auth can-i '*' '*' --all-namespaces
    # Expected Output: yes
    ```

### Phase 2: Configuring Least-Privilege IRSA

This phase establishes the specific IAM Role and Policy required by the application Pod.

1.  **Create Least-Privilege IAM Policy:** Defines the minimum required AWS API permissions (see `my-app-s3-read-policy.json`).

    ```bash
    aws iam create-policy \
        --policy-name MyLeastPrivilegeS3ReadPolicy \
        --policy-document file://my-app-s3-read-policy.json
    ```

2.  **Create IAM Role with OIDC Trust:** The role's Trust Policy (`my-app-trust-policy.json`) must be updated to restrict role assumption only to the designated Service Account (`my-app-sa`) using the cluster's unique OIDC ID.

    ```bash
    aws iam create-role \
        --role-name MyLeastPrivilegeS3Role \
        --assume-role-policy-document file://my-app-trust-policy.json

    aws iam attach-role-policy \
        --role-name MyLeastPrivilegeS3Role \
        --policy-arn arn:aws:iam::<AWS_ACCOUNT_ID>:policy/MyLeastPrivilegeS3ReadPolicy
    ```

### Phase 3: Deploying the IRSA-Enabled Application

This phase creates the Kubernetes Service Account and the Deployment that utilizes it.

1.  **Create Service Account:** Apply the `service-account.yaml`, ensuring the `eks.amazonaws.com/role-arn` annotation points to the `MyLeastPrivilegeS3Role`.

    ```bash
    kubectl apply -f service-account.yaml
    ```

2.  **Deploy Application:** Apply the `my-app-deployment.yaml`. The deployment must specify `serviceAccountName: my-app-sa`.

    ```bash
    kubectl apply -f my-app-deployment.yaml
    ```

---

## ✅ Verification and Validation

Verify that the IRSA mechanism is active and the least-privilege access is enforced.

1.  **Confirm Environment Variable Injection:** Check the running Pod's environment variables to confirm EKS has injected the necessary IRSA configuration.

    ```bash
    POD_NAME=$(kubectl get pods -l app=s3-reader -o jsonpath='{.items[0].metadata.name}')
    kubectl describe pod $POD_NAME | grep AWS_
    ```

    **Expected Validation Output:**

    ```
    AWS_ROLE_ARN:                 arn:aws:iam::<AWS_ACCOUNT_ID>:role/MyLeastPrivilegeS3Role
    AWS_WEB_IDENTITY_TOKEN_FILE:  /var/run/secrets/[eks.amazonaws.com/serviceaccount/token](https://eks.amazonaws.com/serviceaccount/token)
    ```

2.  **Test Least-Privilege Enforcement:** Execute commands inside the Pod to validate access control.

    * **Authorized Access (Should Succeed):**
        ```bash
        kubectl exec -it $POD_NAME -- aws s3 ls s3://my-irsa-data-bucket
        ```
    * **Unauthorized Access (Should Fail with Access Denied):**
        ```bash
        kubectl exec -it $POD_NAME -- aws s3 ls s3://a-random-other-bucket
        ```

---

## 🗑️ Cleanup

To remove all resources created during this demo and prevent future costs, execute the following commands in order.

```bash
# 1. Kubernetes Resource Deletion
kubectl delete deployment s3-reader-app
kubectl delete serviceaccount my-app-sa

# 2. AWS IAM Resource Deletion
aws iam detach-role-policy --role-name MyLeastPrivilegeS3Role --policy-arn arn:aws:iam::<AWS_ACCOUNT_ID>:policy/MyLeastPrivilegeS3ReadPolicy
aws iam delete-policy --policy-arn arn:aws:iam::<AWS_ACCOUNT_ID>:policy/MyLeastPrivilegeS3ReadPolicy
aws iam delete-role --role-name MyLeastPrivilegeS3Role

# 3. EKS Access Entry Deletion
aws eks disassociate-access-policy \
    --cluster-name irsa-least-privilege-demo \
    --principal-arn arn:aws:iam::<AWS_ACCOUNT_ID>:user/DemoUser \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
aws eks delete-access-entry \
    --cluster-name irsa-least-privilege-demo \
    --principal-arn arn:aws:iam::<AWS_ACCOUNT_ID>:user/DemoUser

# 4. Cluster Deletion (Optional)
# aws eks delete-nodegroup --cluster-name irsa-least-privilege-demo --nodegroup-name <YOUR_NODEGROUP_NAME>
# aws eks delete-cluster --name irsa-least-privilege-demo