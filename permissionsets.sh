#!/bin/bash -e

# SSO Instance Details
SSO_INSTANCE=$(aws sso-admin list-instances);
SSO_INSTANCE_ARN=$(echo $SSO_INSTANCE | jq -r '.Instances[0].InstanceArn');
SSO_IDENTITY_STORE=$(echo $SSO_INSTANCE | jq -r '.Instances[0].IdentityStoreId');

SSO_PERMISSION_SETS=$(aws sso-admin list-permission-sets --instance-arn $SSO_INSTANCE_ARN);

#echo Permission Sets\;Session Duration\;AWS Managed Policies\;Inline Policy > pset_report.csv
# echo $SSO_PERMISSION_SETS | jq -r '.PermissionSets[]' | 
#     while read PSET_ARN; do 
#         PSET_DETAILS=$(aws sso-admin describe-permission-set --instance-arn $SSO_INSTANCE_ARN --permission-set-arn $PSET_ARN);
#         PSET_NAME=$(echo $PSET_DETAILS | jq -r .PermissionSet.Name); 
#         PSET_SESSION_TIME=$(echo $PSET_DETAILS | jq -r .PermissionSet.SessionDuration);         
#         PSET_MANAGED_POLICIES=$(aws sso-admin list-managed-policies-in-permission-set --instance-arn $SSO_INSTANCE_ARN --permission-set-arn $PSET_ARN | jq -r '.AttachedManagedPolicies[].Name');
#         PSET_INLINE_POLICY=$(aws sso-admin get-inline-policy-for-permission-set --instance-arn $SSO_INSTANCE_ARN --permission-set-arn $PSET_ARN | jq -r '.InlinePolicy');
#         echo $PSET_NAME\; $PSET_SESSION_TIME\; $PSET_MANAGED_POLICIES\; $PSET_INLINE_POLICY >> pset_report.csv
#         #echo \"$PSET_NAME\"\; \"$PSET_SESSION_TIME\"\; \"$PSET_MANAGED_POLICIES\"\; $PSET_INLINE_POLICY >> pset_report.csv
#     done        

echo Permission Set\;Session Duration\;Type\;Sid\;Action\;Resource\;Effect\;Condition\;NotAction\;AWS Managed Policy\;Permission Set Arn\; > pset_report.csv
echo $SSO_PERMISSION_SETS | jq -r '.PermissionSets[]' | 
    while read PSET_ARN; do 
        echo $PSET_ARN
        PSET_DETAILS=$(aws sso-admin describe-permission-set --instance-arn $SSO_INSTANCE_ARN --permission-set-arn $PSET_ARN);
        PSET_NAME=$(echo $PSET_DETAILS | jq -r .PermissionSet.Name); 
        PSET_SESSION_TIME=$(echo $PSET_DETAILS | jq -r .PermissionSet.SessionDuration);         
        for MANAGED_POLICY in $(aws sso-admin list-managed-policies-in-permission-set --instance-arn $SSO_INSTANCE_ARN --permission-set-arn $PSET_ARN | jq -c '.AttachedManagedPolicies[]'); do
            # echo $PSET_NAME\; $PSET_SESSION_TIME\; AWS Managed\; \;\;\;\;\;\; $MANAGED_POLICY\;$PSET_ARN\;
            # echo $PSET_NAME\; $PSET_SESSION_TIME\; AWS Managed\; \;\;\;\;\;\; $MANAGED_POLICY\;$PSET_ARN\;  >> pset_report.csv    
            POLICY_NAME=$(echo $MANAGED_POLICY | jq -r '.Name');
            POLICY_ARN=$(echo $MANAGED_POLICY | jq -r '.Arn');
            POLICY_VERSION_ID=$(aws iam get-policy --policy-arn $POLICY_ARN | jq -r '.Policy.DefaultVersionId');
            POLICY_STATEMENTS=$(aws iam get-policy-version --policy-arn $POLICY_ARN --version-id $POLICY_VERSION_ID | jq '.PolicyVersion.Document.Statement');
            for STMT in $(echo $POLICY_STATEMENTS | jq -c '.[]'); do
                SID=$(echo $STMT | jq -r '.Sid');
                ACTION=$(echo $STMT | jq -r '.Action');
                RESOURCE=$(echo $STMT | jq -r '.Resource');
                EFFECT=$(echo $STMT | jq -r '.Effect');
                CONDITION=$(echo $STMT | jq -r '.Condition');    
                NOTACTION=$(echo $STMT | jq -r '.NotAction');
                ISACTIONARRAY=${ACTION:0:1};
                ISRESOURCEARRAY=${RESOURCE:0:1};                
                if [ "$ISACTIONARRAY" == "[" ]; then
                    for ACTN in $(echo $STMT | jq '.Action[]'); do
                        if [ "$ISRESOURCEARRAY" == "[" ]; then
                            for RESR in $(echo $STMT | jq '.Resource[]'); do
                                REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; AMP\; $SID\; $ACTN\; $RESR\; $EFFECT\; $CONDITION\; $NOTACTION\; $POLICY_NAME\; $PSET_ARN\; | sed 's/"//g' );
                                #echo $REPORT_DATA
                                echo $REPORT_DATA >> pset_report.csv                            
                            done
                        else
                            REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; AMP\; $SID\; $ACTN\; $RESOURCE\; $EFFECT\; $CONDITION\; $NOTACTION\; $POLICY_NAME\; $PSET_ARN\; | sed 's/"//g' );
                            #echo $REPORT_DATA
                            echo $REPORT_DATA >> pset_report.csv                            
                        fi                    
                    done
                else
                    if [ "$ISRESOURCEARRAY" == "[" ]; then
                        for RESR in $(echo $STMT | jq '.Resource[]'); do
                            REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; AMP\; $SID\; $ACTION\; $RESR\; $EFFECT\; $CONDITION\; $NOTACTION\; $POLICY_NAME\; $PSET_ARN\; | sed 's/"//g' );
                            #echo $REPORT_DATA
                            echo $REPORT_DATA >> pset_report.csv                            
                        done
                    else
                        REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; AMP\; $SID\; $ACTION\; $RESOURCE\; $EFFECT\; $CONDITION\; $NOTACTION\; $POLICY_NAME\; $PSET_ARN\; | sed 's/"//g' );
                        #echo $REPORT_DATA
                        echo $REPORT_DATA >> pset_report.csv                            
                    fi                  
                fi       
            done
        done 

        PSET_INLINE_POLICY=$(aws sso-admin get-inline-policy-for-permission-set --instance-arn $SSO_INSTANCE_ARN --permission-set-arn $PSET_ARN | jq -r '.InlinePolicy' | sed 's/[[:space:]]//g');
        for STMT in $(echo $PSET_INLINE_POLICY | jq -c '.Statement[]'); do
            SID=$(echo $STMT | jq -r '.Sid');
            ACTION=$(echo $STMT | jq -r '.Action');
            RESOURCE=$(echo $STMT | jq -r '.Resource');
            EFFECT=$(echo $STMT | jq -r '.Effect');
            CONDITION=$(echo $STMT | jq -r '.Condition');    
            NOTACTION=$(echo $STMT | jq -r '.NotAction');
            ISACTIONARRAY=${ACTION:0:1};
            ISRESOURCERRAY=${RESOURCE:0:1};
            #echo $PSET_NAME\; $PSET_SESSION_TIME\; Inline\; \; $SID\; $ACTION\; $RESOURCE\; $EFFECT\; $CONDITION\;
            # for ACTN in $(echo $STMT | jq -r '.Action[]'); do
            #     echo $PSET_NAME\; $PSET_SESSION_TIME\; Inline\; \; $SID\; $ACTN\; $RESOURCE\; $EFFECT\; $CONDITION\; $NOTACTION\;$PSET_ARN\; >> pset_report.csv
            # done
            if [ "$ISACTIONARRAY" == "[" ]; then
                for ACTN in $(echo $STMT | jq '.Action[]'); do
                    if [ "$ISRESOURCERRAY" == "[" ]; then
                        for RESR in $(echo $STMT | jq '.Resource[]'); do
                            REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; Inline\; $SID\; $ACTN\; $RESR\; $EFFECT\; $CONDITION\; $NOTACTION\; \; $PSET_ARN\; | sed 's/"//g' );
                            echo $REPORT_DATA >> pset_report.csv                            
                        done
                    else
                        REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; Inline\; $SID\; $ACTN\; $RESOURCE\; $EFFECT\; $CONDITION\; $NOTACTION\; \; $PSET_ARN\; | sed 's/"//g' );
                        echo $REPORT_DATA >> pset_report.csv                        
                    fi                    
                done
            else
                if [ "$ISRESOURCERRAY" == "[" ]; then
                    for RESR in $(echo $STMT | jq '.Resource[]'); do
                        REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; Inline\; $SID\; $ACTION\; $RESR\; $EFFECT\; $CONDITION\; $NOTACTION\; \; $PSET_ARN\; | sed 's/"//g' );
                        echo $REPORT_DATA >> pset_report.csv                        
                    done
                else
                    REPORT_DATA=$(echo $PSET_NAME\; $PSET_SESSION_TIME\; Inline\; $SID\; $ACTION\; $RESOURCE\; $EFFECT\; $CONDITION\; $NOTACTION\; \; $PSET_ARN\; | sed 's/"//g' );
                    echo $REPORT_DATA >> pset_report.csv                                            
                fi                  
            fi       
        done
        #echo \"$PSET_NAME\"\; \"$PSET_SESSION_TIME\"\; \"$PSET_MANAGED_POLICIES\"\; $PSET_INLINE_POLICY >> pset_report.csv
    done  