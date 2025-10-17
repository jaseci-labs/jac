# AWS Deployment Plugin

This plugin automates deploying your jac application to AWS Elastic Beanstalk and managing associated AWS resources like IAM, EC2, and S3.

Follow the steps below to configure your AWS environment and start using the plugin.


---

## Step 1: Create an AWS Account

If you don't already have an AWS account, sign up at:

👉 [https://aws.amazon.com/](https://aws.amazon.com/)

---

## Step 2: Create an IAM User

1. Log in to the **AWS Management Console**
2. Navigate to **IAM → Users → Create user**
3. Provide a username (e.g., `deploy-bot`) and click **Next**
4. Skip permissions for now and click **Create user**

---

## Step 3: Add an Inline Policy

1. Open the newly created user in the IAM console
2. Go to **Permissions → Add inline policy**
3. Select the **JSON** tab and paste the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:CreateInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:GetRole",
        "iam:GetInstanceProfile",
        "iam:PassRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2S3Permissions",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeAvailabilityZones",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:Describe*",
        "ec2:ModifyLaunchTemplate",
        "s3:PutObject",
        "s3:GetObject",
        "s3:CreateBucket",
        "s3:ListBucket"
      ],
      "Resource": "*"
    }
  ]
}
```

4. Click **Review policy**, name it (e.g., `EBDeployPolicy`), and click **Create policy**

---

## Step 4: Attach the Required AWS Managed Policy

1. In the same IAM user permissions section, click **Add permissions → Attach policies directly**
2. Search for and attach the managed policy named:
   ```
   AWSElasticBeanstalkService
   ```

---

## Step 5: Create Access Keys

1. Open your IAM user
2. Go to **Security credentials → Create access key**
3. Choose **Application running outside AWS**, then click **Next**
4. Copy and save your:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

> 💡 **Important:** Keep these keys secure. Do not share or upload them to any public repository.

---

## Step 6: Configure Environment Variables

In the root of your project, create a file named `.env` with the following contents:

```env
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
APP_NAME=your_app_name
```

### Optional Configurable Parameters

```env
AWS_ENV_NAME=your_environment_name   # e.g. myapp-env
AWS_S3_BUCKET=your_s3_bucket_name    # e.g. myapp-deployments
AWS_REGION=us-east-1                 # Default: us-east-1
```

---

## Ready to Deploy!

Your AWS environment is now configured. You can start deploying your application using the plugin.

For more information on usage and advanced configuration, refer to the plugin documentation.

---

## Security Notes

- Never commit your `.env` file to version control
- Add `.env` to your `.gitignore` file
- Rotate your access keys regularly