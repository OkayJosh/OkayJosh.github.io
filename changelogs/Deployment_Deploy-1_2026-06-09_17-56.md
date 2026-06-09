# Deployment Summary: Deploy-1
**Branch:** staging-main
**Base Branch:** main
**Date:** 09 June 2026

## ChatGPT Prompt for AI-Generated Change Log

```
You are an expert software architect and documentation generator.
Using the Git diff below between branch 'staging-main' and main, generate a comprehensive Markdown engineering change log in the following format. 

# {Feature / Fix Title}
**Tracking Ticket:** {ticket link if in commits or branch name}
**Reporter:** {commit author or blank if unknown}
**Department:** Tech
**Prod branch:** staging-main
**Staging branch:** staging-main-staging
**Deployment status:** QA

## Keywords
{comma-separated keywords from diff and branch name}

## Summary
{plain English description of change}

## Architecture Decision Record (ADR)
{Include a brief ADR based on the changes. Outline the Context (why the change was made), the Decision (what was implemented), and the Consequences (impact of this change).}

## System Flow (Mermaid Diagram)
{Generate a Mermaid block diagram representing the architectural flow, component interaction, or data flow changed in this update. Use a ```mermaid block.}

## Thought Process
{step-by-step reasoning for the change}

## Files Changed
NOTE: The following lines of code were added/removed/modified.

| File Directory | Line number | Function / Class | Notes |
| --- | --- | --- | --- |
| {file_path} | {line_numbers} | {function_or_class} | {brief note} |

## How To Test
{steps}

## Expected Criteria
{expected outcomes}

## How to Roll Back
{rollback method}

--- Git Diff ---
diff --git a/.env.sample b/.env.sample
index dfcfdda86..1c84e6e6b 100755
--- a/.env.sample
+++ b/.env.sample
@@ -96,6 +96,9 @@ YOUVERIFY_API_KEY=string
 
 SERVER_ENV=admin
 
+# EFB sub-account transfer approval OTP expiry (minutes)
+RBA_TRANSACTION_OTP_EXPIRY_MINUTES=5
+
 #GUNICORN
 GUNICORN_PORT=8030
 GUNICORN_WORKERS=3
diff --git a/account/models.py b/account/models.py
index 4cf598438..6f73fbea8 100755
--- a/account/models.py
+++ b/account/models.py
@@ -470,6 +470,30 @@ class Profile(models.Model):
             return True
         return False
 
+    def _get_efb_business_for_profile(self):
+        # Deferred import: efb.models imports account.models (circular if top-level).
+        from v2.business_management.efb.models import ExpedierForBusiness
+
+        user = self.user
+        if self.parent and self.parent.user:
+            user = self.parent.user
+
+        return ExpedierForBusiness.objects.filter(
+            user_account_type__user=user
+        ).first()
+
+    def rba_transaction_otpp(self):
+        business = self._get_efb_business_for_profile()
+        if not business:
+            return None
+        return business.rba_transaction_otp
+
+    def enforce_subaccount_transaction_limits_enabled(self):
+        business = self._get_efb_business_for_profile()
+        if not business:
+            return None
+        return business.enforce_subaccount_transaction_limits
+
 class AccountType(models.Model):
     name = models.CharField(max_length=50, unique=True)
     description = models.CharField(max_length=200, null=True, blank=True)
diff --git a/account/serializers/serializers.py b/account/serializers/serializers.py
index da6ba0e41..e98ed73ec 100755
--- a/account/serializers/serializers.py
+++ b/account/serializers/serializers.py
@@ -815,6 +815,10 @@ class ProfileSerializerOut(serializers.ModelSerializer):
     business_name = serializers.CharField(source='get_EFB_business_name.name', read_only=True)
     is_efb_subaccount = serializers.BooleanField(source='efb_subaccount')    
     efb_subaccount_permissions = serializers.SerializerMethodField() 
+    rba_transaction_otp = serializers.BooleanField(source='rba_transaction_otpp')
+    enforce_subaccount_transaction_limits = serializers.BooleanField(
+        source='enforce_subaccount_transaction_limits_enabled'
+    )
     transaction_pin = serializers.BooleanField(source='get_transaction_pin')
     transaction_pin_hashed = serializers.BooleanField(source='is_transaction_pin_hashed')
     bank_accounts = serializers.SerializerMethodField()
diff --git a/account/views.py b/account/views.py
index cc4b8d950..a4170e413 100755
--- a/account/views.py
+++ b/account/views.py
@@ -34,6 +34,7 @@ from account.filters import UserBankAccountFilter, UserRecipientFilter, AccountT
 from account.serializers.admin import UserSummarySerializerOut, UserSerializerIn
 from account.utils import get_client_ip, create_user_meta, process_recipients_update, add_phone_validation_to_users, \
     get_user_with_country_and_phone, handle_exceptions
+from v2.user_management.subaccount_access import get_subaccount_login_block_message
 from account.models import UserVerification, UserBankAccount, UserAccountType, AccountType, Device, UserMeta, \
     UserCountryVerification, Recipient, UserOnboardingSelection, OnboardingOption, OnboardingWalletSelection
 from account.paginations import CustomPagination
@@ -582,7 +583,7 @@ class LoginView(APIView):
                 data['code'] = 'set_password'
                 return Response(data)
             if user_obj.profile.parent and not user_obj.is_active:
-                data['detail'] = 'Account removed or deactivated by your company, please contact support.'
+                data['detail'] = get_subaccount_login_block_message(user_obj)
                 return Response(data, status=status.HTTP_400_BAD_REQUEST)
             
             with StepTimer("authenticate"):
@@ -1383,7 +1384,14 @@ class ReturnUserPhoneNumber(APIView):
             return Response({"detail": "Email and password are required"}, status=status.HTTP_400_BAD_REQUEST)
 
         user_email = email.strip()
-        user_obj = User.objects.filter(username__iexact=user_email).first()
+        # Sub-accounts use a generated username, so we must query by email instead of username
+        user_obj = User.objects.filter(email__iexact=user_email).first()
+        
+        if not user_obj:
+            return Response(
+                {"detail": "Invalid"},
+                status=status.HTTP_401_UNAUTHORIZED)
+
         user = authenticate(request, username=user_obj.username, password=password)
         if user is None:
             return Response(
diff --git a/currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py b/currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py
new file mode 100644
index 000000000..9087336f4
--- /dev/null
+++ b/currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py
@@ -0,0 +1,45 @@
+# Generated by Django 5.2 on 2026-06-08 18:20
+
+import django.db.models.deletion
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        (
+            'account',
+            '0125_recipient_is_favourite',
+        ),
+        (
+            'currency',
+            '0033_currencytransactionlimit_can_request_wallet_and_more',
+        ),
+    ]
+
+    operations = [
+        migrations.RemoveConstraint(
+            model_name='currencytransactionlimit',
+            name='currency_trans_limit',
+        ),
+        migrations.AlterField(
+            model_name='currencytransactionlimit',
+            name='account_type',
+            field=models.ForeignKey(
+                blank=True,
+                null=True,
+                on_delete=django.db.models.deletion.SET_NULL,
+                to='account.accounttype',
+            ),
+        ),
+        migrations.AlterField(
+            model_name='currencytransactionlimit',
+            name='currency',
+            field=models.ForeignKey(
+                blank=True,
+                null=True,
+                on_delete=django.db.models.deletion.SET_NULL,
+                to='currency.currency',
+            ),
+        ),
+    ]
diff --git a/currency/models.py b/currency/models.py
index 32db54c90..d499a0ff6 100755
--- a/currency/models.py
+++ b/currency/models.py
@@ -42,8 +42,8 @@ class Currency(models.Model):
 
 
 class CurrencyTransactionLimit(models.Model):
-    account_type = models.ForeignKey("account.AccountType", on_delete=models.SET_NULL, null=True)
-    currency = models.ForeignKey(Currency, on_delete=models.SET_NULL, null=True)
+    account_type = models.ForeignKey("account.AccountType", on_delete=models.SET_NULL, null=True, blank=True)
+    currency = models.ForeignKey(Currency, on_delete=models.SET_NULL, null=True, blank=True)
     for_verified_user = models.BooleanField(default=False)
     
     # Feature toggles
@@ -90,18 +90,55 @@ class CurrencyTransactionLimit(models.Model):
     def __str__(self):
         return f"{self.id}: {self.currency}"
     
+    @classmethod
+    def get_resolved_limit(cls, account_type, currency, for_verified_user):
+        """
+        Returns the most specific limit available for the given combination.
+        Specificity order:
+        1. Exact match (account_type, currency)
+        2. Match account_type, currency=None
+        3. Match currency, account_type=None
+        4. Global fallback (currency=None, account_type=None)
+        """
+        limits = cls.objects.filter(for_verified_user=for_verified_user)
+        
+        # 1. Exact match
+        exact = limits.filter(account_type=account_type, currency=currency).first()
+        if exact:
+            return exact
+        
+        # 2. Account Type match (wildcard currency)
+        acct_match = limits.filter(account_type=account_type, currency__isnull=True).first()
+        if acct_match:
+            return acct_match
+            
+        # 3. Currency match (wildcard account type)
+        curr_match = limits.filter(account_type__isnull=True, currency=currency).first()
+        if curr_match:
+            return curr_match
+            
+        # 4. Global fallback
+        global_match, _ = cls.objects.get_or_create(
+            account_type=None,
+            currency=None,
+            for_verified_user=for_verified_user
+        )
+        return global_match
+
     def clean(self):
-        if not self.account_type:
-            raise ValidationError("Account Type is required")
+        from django.core.exceptions import ValidationError
+        exists = CurrencyTransactionLimit.objects.filter(
+            account_type=self.account_type,
+            currency=self.currency,
+            for_verified_user=self.for_verified_user
+        ).exclude(pk=self.pk).exists()
+        if exists:
+            raise ValidationError(
+                "A transaction limit with this exact combination of Account Type, Currency, and Verified status already exists."
+            )
     
     class Meta:
-        constraints = [
-            models.UniqueConstraint(
-                name='currency_trans_limit',
-                fields=['currency', 'for_verified_user', 'account_type']
-            )
-        ]
-
+        pass
 
 class ExchangeRate(models.Model):
     account_type = models.ForeignKey('account.AccountType', on_delete=models.SET_NULL, null=True)
diff --git a/currency/serializers.py b/currency/serializers.py
index 0c8fbb9d7..47809510a 100755
--- a/currency/serializers.py
+++ b/currency/serializers.py
@@ -37,11 +37,11 @@ class CurrencySerializerOut(serializers.ModelSerializer):
                 account_type = request.user.profile.account_type
                 verified = request.user.profile.is_verified()
                 
-                limit = CurrencyTransactionLimit.objects.filter(
+                limit = CurrencyTransactionLimit.get_resolved_limit(
                     account_type=account_type,
                     currency=obj,
                     for_verified_user=verified
-                ).first()
+                )
                 
                 if limit:
                     return {
@@ -95,6 +95,15 @@ class ExchangeRateSerializerOut(serializers.ModelSerializer):
 
 
 class CurrencyTransactionLimitSerializerOut(serializers.Serializer):
+    single = serializers.DictField(
+        required=False,
+        default={
+            'account_type': 'account_type.name',
+            'currency_code': 'currency.code',
+            'limit': 0,
+            'left': 0,
+        },
+    )
     monthly = serializers.DictField(default={
         'account_type': 'account_type.name',
         'currency_code': 'currency.code',
diff --git a/expedier/authentication.py b/expedier/authentication.py
index 3b81aaa04..69d65904d 100644
--- a/expedier/authentication.py
+++ b/expedier/authentication.py
@@ -1,6 +1,8 @@
 from rest_framework_simplejwt.authentication import JWTAuthentication
 from rest_framework.exceptions import AuthenticationFailed
 
+from v2.user_management.subaccount_access import enforce_subaccount_access, is_efb_subaccount
+
 
 
 class CustomJWTAuthentication(JWTAuthentication):
@@ -23,7 +25,9 @@ class CustomJWTAuthentication(JWTAuthentication):
     def get_user(self, validated_token):
         user = super().get_user(validated_token)
 
-        if not user.is_active:
+        if is_efb_subaccount(user):
+            enforce_subaccount_access(user)
+        elif not user.is_active:
             raise AuthenticationFailed(
                 "Account is deactivated."
             )
diff --git a/expedier/celery.py b/expedier/celery.py
index 799ca5683..09f6e9f83 100644
--- a/expedier/celery.py
+++ b/expedier/celery.py
@@ -57,8 +57,22 @@ beat_schedule = {
         'schedule': crontab(hour=2, minute=30),
         'options': {'queue': 'celery'}
     },
+
+    'validate-ddt-inventory': {
+        'task': 'v2.virtual_account_management.ddt_tasks.validate_ddt_inventory',
+        'schedule': crontab(minute=0, hour='*/1'),
+        'kwargs': {'batch_size': 50},
+        'options': {'queue': 'celery'}
+    },
+
+    'monitor-ddt-inventory': {
+        'task': 'v2.virtual_account_management.ddt_tasks.monitor_ddt_inventory',
+        'schedule': crontab(minute='*/15'),
+        'options': {'queue': 'celery'}
+    },
 }
 
+
 # Optional: Risk recalculation tasks (can be disabled via environment variable)
 # Set ENABLE_RISK_RECALCULATION=false in .env to disable all risk tasks
 if env.bool('ENABLE_RISK_RECALCULATION', default=True):
diff --git a/expedier/settings/base.py b/expedier/settings/base.py
index a13a1b75b..18c678d4e 100755
--- a/expedier/settings/base.py
+++ b/expedier/settings/base.py
@@ -314,6 +314,7 @@ SUBSCRIPTION_ANNUAL = 12
 SUBSCRIBED_USER_INACTIVITY_DAYS_REMINDER = 3
 UNSUBSCRIBED_USER_INACTIVITY_DAYS_REMINDER = 3
 EFB_MONTHLY_INCOME = env.str("EFB_MONTHLY_INCOME", "5000000+")
+RBA_TRANSACTION_OTP_EXPIRY_MINUTES = env.int("RBA_TRANSACTION_OTP_EXPIRY_MINUTES", default=5)
 INVOICE_REMINDER_DAY_TO_DUE_DATE = 1
 
 # to decide whether we are in PRE-PROD
diff --git a/notification/emails.py b/notification/emails.py
index 2bd71cd29..d9c2c6e79 100755
--- a/notification/emails.py
+++ b/notification/emails.py
@@ -625,6 +625,59 @@ def send_bank_email_otp_to_user(user_id=None, code="", **kwargs):
     return send
 
 
+@shared_task
+def send_rba_transaction_approval_otp_email(
+    parent_user_id,
+    otp_code,
+    business_name,
+    sub_account_name,
+    amount,
+    currency,
+    recipient,
+    initiated_at,
+    expiry_minutes=None,
+):
+    parent_user = get_object_or_404(User, id=parent_user_id)
+    if not otp_code:
+        return False
+
+    if expiry_minutes is None:
+        expiry_minutes = settings.RBA_TRANSACTION_OTP_EXPIRY_MINUTES
+
+    from_email = settings.EMAIL_FROM
+    recipients = [parent_user.email]
+    subject = "Transfer approval required"
+    content = (
+        f"Hello, {business_name},<br><br>"
+        f"{sub_account_name} has initiated a transfer that requires your approval.<br><br>"
+        f"<b>Transaction Details</b><br><br>"
+        f"Initiated By: {sub_account_name}<br>"
+        f"Amount: {currency} {amount}<br>"
+        f"Recipient: {recipient}<br>"
+        f"Date &amp; Time: {initiated_at}<br><br>"
+        f"<b>Approval Code (OTP):</b><br>"
+        f"<span style=\"font-size: 24px; font-weight: bold; color: #000000; letter-spacing: 2px;\">"
+        f"{otp_code}"
+        f"</span><br><br>"
+        f"If you approve this transfer, please share this OTP with {sub_account_name}. "
+        f"They will need it to complete the transaction.<br><br>"
+        f"If you do not recognize this request or do not wish to approve the transfer, "
+        f"do not share the OTP. The transaction cannot proceed without your authorization.<br><br>"
+        f"For security reasons, this OTP will expire in {expiry_minutes} minutes.<br><br>"
+        f"Thank you,"
+    )
+    send = send_mail(
+        subject=subject,
+        from_email=from_email,
+        message=content,
+        html_message=content,
+        recipient_list=recipients,
+        fail_silently=True,
+    )
+    log.info(send)
+    return send
+
+
 def send_bank_email_removal_otp_to_user(user, code, **kwargs):
     site_details = get_site_details()
     email = kwargs.get('email')
diff --git a/transaction/serializers/user.py b/transaction/serializers/user.py
index 98a9c3d28..26e04a5a1 100755
--- a/transaction/serializers/user.py
+++ b/transaction/serializers/user.py
@@ -358,6 +358,25 @@ class AssetTransferSerializerIn(serializers.ModelSerializer):
 
     def validate(self, validated_data):
         external_transfer = validated_data.get('external_transfer')
+        email = validated_data.get('email')
+        account_number = validated_data.get('account_number')
+        
+        if external_transfer and (email or account_number):
+            from v2.user_management.transactions.utils import check_and_intercept_internal_transfer
+            interception = check_and_intercept_internal_transfer(
+                account_number=account_number or email, 
+                sender_user=validated_data.get('user')
+            )
+            if interception:
+                external_transfer = False
+                validated_data['external_transfer'] = False
+                validated_data['recipient'] = interception['recipient_identifier']
+                
+                # clear external banking details
+                for field in ['bank_name', 'bank_code', 'account_number', 'routing_number', 'sort_code', 'iban', 'swift_bic']:
+                    if field in validated_data:
+                        validated_data[field] = None
+
         pay_with = validated_data.get('pay_with')
         user = validated_data.get('user')
 
@@ -372,10 +391,11 @@ class AssetTransferSerializerIn(serializers.ModelSerializer):
             if len(routing_number) < 9:
                 raise InvalidRequestException({'detail': 'Routing number should be 9 digits'})
 
-        user_version = str(user.profile.app_version).replace('.', '')
-        if str(user_version).isnumeric() and int(user_version) > 209:
-            if not user.profile.verify_transaction_pin(transaction_pin):
-                raise InvalidRequestException({'detail': 'Incorrect transaction pin'})
+        request = self.context.get("request")
+        logged_in_user = getattr(request, "logged_in_user", user) if request else user
+
+        if not logged_in_user.profile.verify_transaction_pin(transaction_pin):
+            raise InvalidRequestException({'detail': 'Incorrect transaction pin'})
 
         if external_transfer and not user.profile.is_verified():
             raise InvalidRequestException({'detail': EXTERNAL_VERIFICATION_ERROR})
diff --git a/transaction/tests/test_interac_interception.py b/transaction/tests/test_interac_interception.py
new file mode 100644
index 000000000..7fbcf2ef4
--- /dev/null
+++ b/transaction/tests/test_interac_interception.py
@@ -0,0 +1,122 @@
+from decimal import Decimal
+from unittest.mock import patch
+from django.test import TestCase
+
+from factories.base import (
+    UserFactory,
+    WalletFactory,
+    CurrencyFactory,
+)
+from account.models import UserBankAccount
+from wallet.models import DDTAssignment, DDTAssignmentStatus, Wallet
+from transaction.serializers.user import AssetTransferSerializerIn
+
+class InteracInterceptionTests(TestCase):
+    def setUp(self):
+        self.sender = UserFactory(email="sender@example.com")
+        self.recipient = UserFactory(email="recipient@example.com")
+        
+        self.cad = CurrencyFactory(code="CAD")
+        
+        self.sender_wallet = Wallet.objects.create(
+            user=self.sender,
+            currency=self.cad,
+            balance=Decimal("1000.00"),
+            active=True,
+            status='approved'
+        )
+        self.recipient_wallet = Wallet.objects.create(
+            user=self.recipient,
+            currency=self.cad,
+            balance=Decimal("0.00"),
+            active=True,
+            status='approved'
+        )
+        
+        self.uba = UserBankAccount.objects.create(
+            user=self.recipient,
+            account_number=self.recipient.email,
+            bank_name="Interac",
+            active=True
+        )
+        
+        DDTAssignment.objects.create(
+            user_id=self.recipient.id,
+            user_bank_account=self.uba,
+            status=DDTAssignmentStatus.ACTIVE,
+            ddt_number="DDT-TEST"
+        )
+        
+    @patch('transaction.serializers.user.get_transaction_limit', return_value=(True, {}))
+    @patch('transaction.serializers.user.is_balance_consistent', return_value=True)
+    def test_interac_interception(self, mock_is_balance_consistent, mock_limit):
+        data = {
+            "amount": "50.00",
+            "currency": self.cad.id,
+            "external_transfer": True,
+            "bank_name": "Interac",
+            "email": self.recipient.email,
+            "account_name": "Recipient Name",
+        }
+        
+        class MockUser:
+            def __init__(self, user):
+                self.user = user
+                self.profile = user.profile
+                
+        # To avoid complex mock setups for the serializer, we just test the `validate` method manually.
+        serializer = AssetTransferSerializerIn()
+        
+        validated_data = data.copy()
+        validated_data['user'] = self.sender
+        validated_data['currency'] = self.cad
+        
+        # We only care that the external_transfer flag is flipped and recipient is set
+        result = serializer.validate(validated_data)
+        
+        self.assertFalse(result.get('external_transfer'))
+        self.assertEqual(result.get('recipient'), self.recipient.email)
+        self.assertIsNone(result.get('bank_name'))
+
+    @patch('transaction.serializers.user.get_transaction_limit', return_value=(True, {}))
+    @patch('transaction.serializers.user.is_balance_consistent', return_value=True)
+    def test_interac_withdrawal_to_own_email_not_intercepted(self, mock_is_balance_consistent, mock_limit):
+        """
+        If a user attempts to send an Interac to their OWN email address (which happens to be assigned
+        to their virtual account), it should NOT be intercepted as an internal transfer.
+        This prevents the 'You cannot transfer to yourself' error on withdrawals.
+        """
+        # Assign the sender's email as an active DDT virtual account
+        sender_uba = UserBankAccount.objects.create(
+            user=self.sender,
+            account_number=self.sender.email,
+            bank_name="Interac",
+            active=True
+        )
+        DDTAssignment.objects.create(
+            user_id=self.sender.id,
+            user_bank_account=sender_uba,
+            status=DDTAssignmentStatus.ACTIVE,
+            ddt_number="DDT-SENDER"
+        )
+
+        data = {
+            "amount": "50.00",
+            "currency": self.cad.id,
+            "external_transfer": True,
+            "bank_name": "Interac",
+            "email": self.sender.email,  # SENDER'S email!
+            "account_name": "Sender Name",
+        }
+
+        serializer = AssetTransferSerializerIn()
+
+        validated_data = data.copy()
+        validated_data['user'] = self.sender
+        validated_data['currency'] = self.cad
+
+        result = serializer.validate(validated_data)
+
+        # Should NOT intercept! external_transfer should remain True
+        self.assertTrue(result.get('external_transfer'))
+        self.assertEqual(result.get('email'), self.sender.email)
diff --git a/transaction/utils/misc.py b/transaction/utils/misc.py
index c516ab2b4..67adab64f 100755
--- a/transaction/utils/misc.py
+++ b/transaction/utils/misc.py
@@ -68,7 +68,6 @@ INTERNAL_TRANSACTION_TYPES = {
     'swap currency',
     'asset conversion',
     'conversion',
-    'internal transfer',
 }
 
 EXTERNAL_VERIFICATION_ERROR = 'Please verify your account to send funds externally.'
@@ -93,9 +92,11 @@ def should_enforce_verification(
     if lowered_type in INTERNAL_TRANSACTION_TYPES:
         return False
 
+    if lowered_type == 'internal transfer':
+        return True
+
     if lowered_type in EXTERNAL_TRANSACTION_TYPES:
-        if external_transfer is not None:
-            return bool(external_transfer)
+        # Both external and internal (external_transfer=False) transfers require verification
         return True
 
     return False
@@ -164,7 +165,7 @@ def get_transaction_limit(user, transaction_type, currency=None, **kwargs):
     # Get currency transaction limits
     currency_limit = None
     if currency:
-        currency_limit, _ = CurrencyTransactionLimit.objects.get_or_create(
+        currency_limit = CurrencyTransactionLimit.get_resolved_limit(
             currency=currency,
             for_verified_user=user_verified,
             account_type=account_type,
@@ -755,8 +756,11 @@ def get_user_transactions_limit_left(user, transaction_type, currency, **kwargs)
 
     user_verified = user.profile.is_verified()
 
-    limit, _ = CurrencyTransactionLimit.objects.get_or_create(account_type=account_type,
-                                                              for_verified_user=user_verified, currency=currency)
+    limit = CurrencyTransactionLimit.get_resolved_limit(
+        account_type=account_type,
+        for_verified_user=user_verified, 
+        currency=currency
+    )
 
     if transaction_type in ['transfer', 'asset transfer', 'fund transfer']:
         month_tx = user.assettransfer_set.filter(month_query).filter(wallet__currency=currency).aggregate(
@@ -770,8 +774,15 @@ def get_user_transactions_limit_left(user, transaction_type, currency, **kwargs)
         daily_limit = limit.max_daily_external_transfer_amount
         weekly_limit = limit.max_weekly_external_transfer_amount
         monthly_limit = limit.max_monthly_external_transfer_amount
+        single_limit = limit.max_single_external_transfer_amount
 
         result = {
+            'single': {
+                'account_type': account_type.name,
+                'currency_code': currency.code,
+                'limit': float(single_limit),
+                'left': float(single_limit),
+            },
             'monthly': {
                 'account_type': account_type.name,
                 'currency_code': currency.code,
diff --git a/transaction/views/user.py b/transaction/views/user.py
index 40d9ee969..d2ff987c8 100755
--- a/transaction/views/user.py
+++ b/transaction/views/user.py
@@ -36,8 +36,10 @@ from transaction.utils.utils import handle_exceptions
 from rest_framework import viewsets
 from rest_framework.permissions import IsAuthenticated
 from rest_framework.request import Request
+from rest_framework.exceptions import ValidationError
 from v2.business_management.services import ExpedierBusinessCreation
 from v2.business_management.efb.permissions import EffectiveUserPermission
+from v2.user_management.efb_subaccounts import SubAccountLimitService
 
 import time
 ## Step Timer analysis
@@ -165,7 +167,19 @@ class AssetTransferView(generics.ListCreateAPIView):
         context = {'request': request}
         serializer = AssetTransferSerializerIn(data=request.data, context=context)
         serializer.is_valid() or raise_serializer_error_msg(errors=serializer.errors)
-        success, response = serializer.save()
+
+        try:
+            success, response = SubAccountLimitService.complete_transfer(
+                request=request,
+                currency=serializer.validated_data.get("currency"),
+                amount=serializer.validated_data.get("amount"),
+                transfer_callable=serializer.save,
+            )
+        except ValidationError as e:
+            # e.detail is already {"detail": "..."}; avoid double-wrapping for EFB clients.
+            body = e.detail if isinstance(e.detail, dict) else {"detail": e.detail}
+            return Response(body, status=status.HTTP_400_BAD_REQUEST)
+
         if not success:
             data['detail'] = 'an error occurred'
             data['errors'] = response
diff --git a/v2/business_management/efb/admin.py b/v2/business_management/efb/admin.py
index 3d2f4f1f9..74059eb6a 100644
--- a/v2/business_management/efb/admin.py
+++ b/v2/business_management/efb/admin.py
@@ -3,7 +3,8 @@ from account.models import UserAccountType
 from v2.business_management.efb.models import (ExpedierForBusiness, BusinessOwner, 
 Invoice, InvoiceItem, Employee, PaidSalary, SubscriptionPlan, BusinessSubscriptionPlan, 
 BusinessJurisdiction, ZohoSignWebhookEvent, BusinessJurisdiction, SubscriptionPlanFeature, BusinessSubscriptionHistory, 
-EFBSubAccountInvitation, SubAccountPermission)
+EFBSubAccountInvitation, SubAccountPermission, SubAccountTransactionLimit,
+SubAccountDailyUsage, SubAccountTransactionAuthorization)
 from .utils import SubscriptionDurationChange as SDC
 from .forms import SubscriptionDurationForm
 
@@ -237,4 +238,82 @@ class UserInvitationAdmin(admin.ModelAdmin):
     list_display = ['id', 'name', 'email', 'invited_by', 'token', 'status', 'is_accepted', 'expires_at', 'created_at', 'updated_at']
     list_filter = ['status', 'is_accepted', 'role', 'expires_at', 'created_at']
     search_fields = ['name', 'email', 'invited_by__email', 'role', 'token']
-    readonly_fields = ['token', 'created_at', 'updated_at']
\ No newline at end of file
+    readonly_fields = ['token', 'created_at', 'updated_at']
+
+
+@admin.register(SubAccountTransactionAuthorization)
+class SubAccountTransactionAuthorizationAdmin(admin.ModelAdmin):
+    list_display = (
+        "user",
+        "business",
+        "currency",
+        "amount",
+        "otp",
+        "is_used",
+        "created_at",
+        "expires_at",
+        "status_display",
+    )
+    list_filter = ("is_used", "business", "created_at")
+    search_fields = ("user__email", "user__username", "business__name")
+    autocomplete_fields = ("user", "business")
+    readonly_fields = ("otp", "created_at", "expires_at")
+    ordering = ("-created_at",)
+
+    def status_display(self, obj):
+        if obj.is_used:
+            return "Used"
+        if obj.is_expired():
+            return "Expired"
+        return "Active"
+
+    status_display.short_description = "Status"
+
+
+@admin.register(SubAccountTransactionLimit)
+class SubAccountTransactionLimitAdmin(admin.ModelAdmin):
+    list_display = (
+        "id",
+        "sub_account",
+        "business",
+        "currency",
+        "single_limit",
+        "daily_limit",
+        "created_at",
+        "updated_at",
+    )
+    search_fields = (
+        "sub_account__email",
+        "sub_account__username",
+        "business__name",
+        "currency__code",
+        "currency__name",
+    )
+    list_filter = ("currency", "created_at", "updated_at")
+    autocomplete_fields = ("sub_account", "business", "currency")
+    readonly_fields = ("created_at", "updated_at")
+    ordering = ("-created_at",)
+
+
+@admin.register(SubAccountDailyUsage)
+class SubAccountDailyUsageAdmin(admin.ModelAdmin):
+    list_display = (
+        "id",
+        "sub_account",
+        "business",
+        "currency",
+        "total_amount",
+        "usage_date",
+        "created_at",
+    )
+    search_fields = (
+        "sub_account__email",
+        "sub_account__username",
+        "business__name",
+        "currency__code",
+        "currency__name",
+    )
+    list_filter = ("currency", "created_at")
+    autocomplete_fields = ("sub_account", "business", "currency")
+    readonly_fields = ("created_at",)
+    ordering = ("-created_at",)
\ No newline at end of file
diff --git a/v2/business_management/efb/choices.py b/v2/business_management/efb/choices.py
index b9a0ad0e7..5ffa2ef12 100644
--- a/v2/business_management/efb/choices.py
+++ b/v2/business_management/efb/choices.py
@@ -48,8 +48,14 @@ SUBSCRIPTION_EVENT_CHOICES = (
     ("expired", "Expired"),
 )
 
+SUBACCOUNT_STATUS_ACTIVE = "active"
+SUBACCOUNT_STATUS_PENDING = "pending"
+SUBACCOUNT_STATUS_DEACTIVATED = "deactivated"
+SUBACCOUNT_STATUS_REMOVED = "removed"
+
 INVITATION_STATUS_CHOICES = (
-    ("active", "Active"),
-    ("pending", "Pending"),
-    ("deactivated", "Deactivated"),
+    (SUBACCOUNT_STATUS_ACTIVE, "Active"),
+    (SUBACCOUNT_STATUS_PENDING, "Pending"),
+    (SUBACCOUNT_STATUS_DEACTIVATED, "Deactivated"),
+    (SUBACCOUNT_STATUS_REMOVED, "Removed"),
 )
\ No newline at end of file
diff --git a/v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py b/v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py
new file mode 100644
index 000000000..34f9ba2f2
--- /dev/null
+++ b/v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py
@@ -0,0 +1,70 @@
+# Generated by Django 5.1.5 on 2026-06-02 17:27
+
+import django.db.models.deletion
+import django.utils.timezone
+from django.conf import settings
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        ('currency', '0033_currencytransactionlimit_can_request_wallet_and_more'),
+        ('efb', '0012_subaccountpermission'),
+        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
+    ]
+
+    operations = [
+        migrations.AddField(
+            model_name='expedierforbusiness',
+            name='rba_transaction_otp',
+            field=models.BooleanField(default=False),
+        ),
+        migrations.CreateModel(
+            name='SubAccountDailyUsage',
+            fields=[
+                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
+                ('total_amount', models.DecimalField(decimal_places=2, default=0, max_digits=20)),
+                ('usage_date', models.DateField(default=django.utils.timezone.now)),
+                ('created_at', models.DateTimeField(auto_now_add=True)),
+                ('business', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='efb.expedierforbusiness')),
+                ('currency', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='currency_limits', to='currency.currency')),
+                ('sub_account', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='daily_usages', to=settings.AUTH_USER_MODEL)),
+            ],
+            options={
+                'unique_together': {('sub_account', 'business', 'currency', 'usage_date')},
+            },
+        ),
+        migrations.CreateModel(
+            name='SubAccountTransactionAuthorization',
+            fields=[
+                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
+                ('amount', models.DecimalField(decimal_places=2, default=0.0, max_digits=12)),
+                ('otp', models.CharField(max_length=6)),
+                ('is_used', models.BooleanField(default=False)),
+                ('created_at', models.DateTimeField(auto_now_add=True)),
+                ('expires_at', models.DateTimeField()),
+                ('business', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='efb.expedierforbusiness')),
+                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
+            ],
+            options={
+                'indexes': [models.Index(fields=['user', 'business'], name='efb_subacco_user_id_76abd5_idx')],
+            },
+        ),
+        migrations.CreateModel(
+            name='SubAccountTransactionLimit',
+            fields=[
+                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
+                ('single_limit', models.DecimalField(decimal_places=2, max_digits=20)),
+                ('daily_limit', models.DecimalField(decimal_places=2, max_digits=20)),
+                ('created_at', models.DateTimeField(auto_now_add=True)),
+                ('updated_at', models.DateTimeField(auto_now=True)),
+                ('business', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='transaction_limits', to='efb.expedierforbusiness')),
+                ('currency', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='transaction_limits_currency', to='currency.currency')),
+                ('sub_account', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='transaction_limits', to=settings.AUTH_USER_MODEL)),
+            ],
+            options={
+                'unique_together': {('sub_account', 'business', 'currency')},
+            },
+        ),
+    ]
diff --git a/v2/business_management/efb/migrations/0014_subaccountpermission_status.py b/v2/business_management/efb/migrations/0014_subaccountpermission_status.py
new file mode 100644
index 000000000..c4a7a6222
--- /dev/null
+++ b/v2/business_management/efb/migrations/0014_subaccountpermission_status.py
@@ -0,0 +1,39 @@
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        ("efb", "0013_expedierforbusiness_rba_transaction_otp_and_more"),
+    ]
+
+    operations = [
+        migrations.AddField(
+            model_name="subaccountpermission",
+            name="status",
+            field=models.CharField(
+                choices=[
+                    ("active", "Active"),
+                    ("pending", "Pending"),
+                    ("deactivated", "Deactivated"),
+                    ("removed", "Removed"),
+                ],
+                default="active",
+                max_length=20,
+            ),
+        ),
+        migrations.AlterField(
+            model_name="efbsubaccountinvitation",
+            name="status",
+            field=models.CharField(
+                choices=[
+                    ("active", "Active"),
+                    ("pending", "Pending"),
+                    ("deactivated", "Deactivated"),
+                    ("removed", "Removed"),
+                ],
+                default="pending",
+                max_length=20,
+            ),
+        ),
+    ]
diff --git a/v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py b/v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py
new file mode 100644
index 000000000..7e6ecb877
--- /dev/null
+++ b/v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py
@@ -0,0 +1,24 @@
+# Generated by Django 5.1.5
+
+import django.db.models.deletion
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        ('currency', '0033_currencytransactionlimit_can_request_wallet_and_more'),
+        ('efb', '0014_subaccountpermission_status'),
+    ]
+
+    operations = [
+        migrations.AddField(
+            model_name='subaccounttransactionauthorization',
+            name='currency',
+            field=models.ForeignKey(
+                on_delete=django.db.models.deletion.PROTECT,
+                to='currency.currency',
+            ),
+            preserve_default=False,
+        ),
+    ]
diff --git a/v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py b/v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py
new file mode 100644
index 000000000..daaed4e3d
--- /dev/null
+++ b/v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py
@@ -0,0 +1,18 @@
+# Generated by Django 5.1.5 on 2026-06-03 12:34
+
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        ('efb', '0015_subaccounttransactionauthorization_currency'),
+    ]
+
+    operations = [
+        migrations.AddField(
+            model_name='expedierforbusiness',
+            name='enforce_subaccount_transaction_limits',
+            field=models.BooleanField(default=False),
+        ),
+    ]
diff --git a/v2/business_management/efb/models.py b/v2/business_management/efb/models.py
index 622d321a9..1de5b6d52 100644
--- a/v2/business_management/efb/models.py
+++ b/v2/business_management/efb/models.py
@@ -1,5 +1,6 @@
 import uuid
 from django.db import models
+from django.db import transaction
 from django.utils.timezone import now
 from django.conf import settings
 from datetime import timedelta
@@ -147,6 +148,8 @@ class ExpedierForBusiness(models.Model):
     agent_kyc_steps = models.TextField(blank=True, null=True, verbose_name="What KYC/due diligence steps are conducted by your agents?")
     processes_governed = models.BooleanField(default=False, verbose_name="Are those KYC processes governed by your firm?")
     monitoring_method = models.TextField(blank=True, null=True, verbose_name="How do you monitor your agents to ensure onboarding compliance?")
+    rba_transaction_otp = models.BooleanField(default=False)
+    enforce_subaccount_transaction_limits = models.BooleanField(default=False)
 
     def __str__(self) -> str:
         """
@@ -539,6 +542,7 @@ class EFBSubAccountInvitation(models.Model):
 class SubAccountPermission(models.Model):
     sub_account = models.ForeignKey(User, on_delete=models.CASCADE, related_name="sub_permissions")
     business = models.ForeignKey(ExpedierForBusiness, on_delete=models.CASCADE, related_name="sub_permissions")
+    status = models.CharField(max_length=20, choices=INVITATION_STATUS_CHOICES, default="active")
     can_view_transactions = models.BooleanField(default=False)
     can_view_account_details = models.BooleanField(default=False)
     can_swap_funds = models.BooleanField(default=False)
@@ -555,5 +559,82 @@ class SubAccountPermission(models.Model):
         return f"{self.sub_account.email} permissions for {self.business.name}"
 
 
+class SubAccountTransactionLimit(models.Model):
+    sub_account = models.ForeignKey(
+        User,
+        on_delete=models.CASCADE,
+        related_name="transaction_limits"
+    )
+    business = models.ForeignKey(
+        ExpedierForBusiness,
+        on_delete=models.CASCADE,
+        related_name="transaction_limits"
+    )
+    currency = models.ForeignKey(
+        Currency,
+        on_delete=models.CASCADE,
+        related_name="transaction_limits_currency"
+    )
+    single_limit = models.DecimalField(max_digits=20, decimal_places=2)
+    daily_limit = models.DecimalField(max_digits=20, decimal_places=2)
+    created_at = models.DateTimeField(auto_now_add=True)
+    updated_at = models.DateTimeField(auto_now=True)
+
+    class Meta:
+        unique_together = ("sub_account", "business", "currency")
+
+    def __str__(self):
+        return f"{self.sub_account} - {self.currency}"
+
+
+class SubAccountDailyUsage(models.Model):
+    sub_account = models.ForeignKey(
+        User,
+        on_delete=models.CASCADE,
+        related_name="daily_usages"
+    )
+    business = models.ForeignKey(
+        ExpedierForBusiness,
+        on_delete=models.CASCADE
+    )
+    currency = models.ForeignKey(
+        Currency,
+        on_delete=models.CASCADE,
+        related_name="currency_limits"
+    )
+    total_amount = models.DecimalField(max_digits=20, decimal_places=2, default=0)
+    usage_date = models.DateField(default=timezone.now)
+    created_at = models.DateTimeField(auto_now_add=True)
+
+    class Meta:
+        unique_together = ("sub_account", "business", "currency", "usage_date")
+
+
+class SubAccountTransactionAuthorization(models.Model):
+    user = models.ForeignKey(User, on_delete=models.CASCADE)
+    business = models.ForeignKey(ExpedierForBusiness, on_delete=models.CASCADE)
+    currency = models.ForeignKey(Currency, on_delete=models.PROTECT)
+    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
+    otp = models.CharField(max_length=6)
+    is_used = models.BooleanField(default=False)
+    created_at = models.DateTimeField(auto_now_add=True)
+    expires_at = models.DateTimeField()
+
+    class Meta:
+        indexes = [
+            models.Index(fields=["user", "business"]),
+        ]
+
+    def is_expired(self):
+        return timezone.now() > self.expires_at
+
+    def mark_as_used(self):
+        with transaction.atomic():
+            otp = SubAccountTransactionAuthorization.objects.select_for_update().get(pk=self.pk)
+            if not otp.is_used:
+                otp.is_used = True
+                otp.save(update_fields=["is_used"])
+
+
 
 
diff --git a/v2/business_management/efb/permissions.py b/v2/business_management/efb/permissions.py
index 1930331ad..2911f205d 100644
--- a/v2/business_management/efb/permissions.py
+++ b/v2/business_management/efb/permissions.py
@@ -3,6 +3,8 @@ from rest_framework.permissions import BasePermission
 from rest_framework.exceptions import PermissionDenied
 from rest_framework.exceptions import ValidationError
 from v2.business_management.efb.models import SubAccountPermission
+from v2.business_management.efb.choices import SUBACCOUNT_STATUS_ACTIVE
+from v2.user_management.subaccount_access import get_subaccount_permission
 from v2.business_management.efb.verifications import (
 validate_verified_efb_user, validate_active_subscription, 
 efb_business_suite_validation, get_verification_status, efb_user_account_type)
@@ -40,6 +42,14 @@ class EffectiveUserPermission(BasePermission):
             return True
 
         if request.logged_in_user != request.user:
+            subaccount_permission = get_subaccount_permission(request.logged_in_user)
+            if (
+                not request.logged_in_user.is_active
+                or subaccount_permission is None
+                or subaccount_permission.status != SUBACCOUNT_STATUS_ACTIVE
+            ):
+                raise ValidationError({"detail": "Your account is not permitted to access this resource"})
+
             required_permission = getattr(view, "required_permission", None)
             
             if not required_permission:
diff --git a/v2/business_management/efb/serializers.py b/v2/business_management/efb/serializers.py
index c5b46703c..d70646d27 100644
--- a/v2/business_management/efb/serializers.py
+++ b/v2/business_management/efb/serializers.py
@@ -1,5 +1,10 @@
 import logging
 import random
+import uuid
+from datetime import timedelta
+from decimal import Decimal, ROUND_HALF_UP
+from django.conf import settings
+from django.contrib.auth import get_user_model
 
 from django.core.signing import TimestampSigner
 from django.db import models, transaction
@@ -7,7 +12,6 @@ from django.urls import reverse
 from django.utils import timezone
 from django.utils.timezone import datetime
 from rest_framework import serializers
-from decimal import Decimal, ROUND_HALF_UP
 
 from account.models import (
     AccountType,
@@ -18,7 +22,8 @@ from account.models import (
     UserAccountType, Location, State
 )
 from account.serializers.serializers import UserLocationSerializerOut
-from currency.models import Currency, ExchangeRate
+from currency.models import Currency, CurrencyTransactionLimit, ExchangeRate
+from notification.emails import send_rba_transaction_approval_otp_email
 from expedier.settings.base import EFB_MONTHLY_INCOME
 from transaction.choices import transaction_fee_choices, transaction_type_choices
 from transaction.models import AssetConversion, AssetTransfer, Transaction
@@ -35,6 +40,8 @@ from v2.business_management.efb.models import (
     SubscriptionPlan,
     EFBSubAccountInvitation,
     SubAccountPermission,
+    SubAccountTransactionLimit,
+    SubAccountTransactionAuthorization,
 )
 from v2.business_management.services import ExpedierBusinessCreation
 from wallet.models import FundWallet, Wallet
@@ -43,6 +50,7 @@ from modules.subscription import SubscriptionService
 
 from .choices import SUBSCRIPTION_DURATION_CHOICES
 from .utils import send_invoice_email, verify_invoice_no, send_payslip_email, get_business_name
+from v2.user_management.efb_subaccounts import SubAccountLimitService
 
 log = logging.getLogger(__name__)
 
@@ -1364,6 +1372,15 @@ class SubAccountInviteRequestSerializer(serializers.Serializer):
     email = serializers.EmailField()
     name = serializers.CharField(max_length=255)
 
+
+class SubAccountRemoveRequestSerializer(serializers.Serializer):
+    email = serializers.EmailField()
+
+
+class SubAccountRemoveResponseSerializer(serializers.Serializer):
+    detail = serializers.CharField()
+
+
 class SubAccountInvitationSerializer(serializers.ModelSerializer):
     class Meta:
         model = EFBSubAccountInvitation
@@ -1419,6 +1436,9 @@ class SubAccountSerializer(serializers.ModelSerializer):
         return access_list
 
     def get_status(self, obj):
+        if obj.status:
+            return obj.status
+
         invitation = EFBSubAccountInvitation.objects.filter(
             email=obj.sub_account.email
         ).first()
@@ -1470,6 +1490,478 @@ class PendingSubAccountSerializer(serializers.ModelSerializer):
         return []
 
 
+class TransactionLimitItemSerializer(serializers.Serializer):
+    currency = serializers.IntegerField(min_value=1)
+    single_limit = serializers.DecimalField(
+        max_digits=20,
+        decimal_places=2,
+        min_value=Decimal("0.01"),
+    )
+    daily_limit = serializers.DecimalField(
+        max_digits=20,
+        decimal_places=2,
+        min_value=Decimal("0.01"),
+    )
+
+    def validate(self, attrs):
+        if attrs["daily_limit"] < attrs["single_limit"]:
+            raise serializers.ValidationError(
+                {"detail": "Daily limit cannot be less than single limit"}
+            )
+        return attrs
+
+
+class SubAccountTransactionLimitSerializer(serializers.Serializer):
+    email = serializers.EmailField()
+    limits = serializers.ListField(
+        child=TransactionLimitItemSerializer(),
+        allow_empty=False,
+    )
+
+    def create(self, validated_data):
+        request = self.context["request"]
+        user_account_type = UserAccountType.objects.filter(
+            user=request.user,
+            account_type__name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER,
+        ).first()
+
+        if not user_account_type:
+            raise serializers.ValidationError({"detail": "User have no business record"})
+
+        business = user_account_type.business
+        if not business:
+            raise serializers.ValidationError({"detail": "Business not found"})
+        User = get_user_model()
+
+        try:
+            sub_account = User.objects.get(email=validated_data["email"])
+        except User.DoesNotExist:
+            raise serializers.ValidationError({"detail": "Invalid sub account"})
+
+        if not SubAccountPermission.objects.filter(
+            sub_account=sub_account,
+            business=business,
+        ).exists():
+            raise serializers.ValidationError({
+                "detail": "User is not a sub-account of this business"
+            })
+
+        with transaction.atomic():
+            for item in validated_data["limits"]:
+                SubAccountLimitService.update_or_create_limit(
+                    sub_account=sub_account,
+                    business=business,
+                    currency=item["currency"],
+                    single_limit=item["single_limit"],
+                    daily_limit=item["daily_limit"],
+                )
+
+        return SubAccountTransactionLimit.objects.filter(
+            sub_account=sub_account,
+            business=business,
+        ).select_related("currency")
+
+
+class FlexibleBooleanField(serializers.Field):
+    """Accept bool or string values such as true/false."""
+
+    def to_internal_value(self, data):
+        if isinstance(data, bool):
+            return data
+        if isinstance(data, str):
+            return data.lower() == "true"
+        if data is None:
+            raise serializers.ValidationError("This field is required.")
+        return bool(data)
+
+    def to_representation(self, value):
+        return bool(value)
+
+
+class SetRBATransactionAuthorizationSerializer(serializers.Serializer):
+    rba_transaction_otp = FlexibleBooleanField(required=False)
+    enforce_subaccount_transaction_limits = FlexibleBooleanField(required=False)
+
+    def validate(self, attrs):
+        if not attrs:
+            raise serializers.ValidationError({"detail": "No settings provided to update"})
+        return attrs
+
+    def save(self, **kwargs):
+        business = self.context["business"]
+        update_fields = []
+
+        if "rba_transaction_otp" in self.validated_data:
+            business.rba_transaction_otp = self.validated_data["rba_transaction_otp"]
+            update_fields.append("rba_transaction_otp")
+
+        if "enforce_subaccount_transaction_limits" in self.validated_data:
+            business.enforce_subaccount_transaction_limits = self.validated_data[
+                "enforce_subaccount_transaction_limits"
+            ]
+            update_fields.append("enforce_subaccount_transaction_limits")
+
+        business.save(update_fields=update_fields)
+        return business
+
+
+class SetRBATransactionAuthorizationResponseSerializer(serializers.Serializer):
+    detail = serializers.CharField()
+    rba_transaction_otp = serializers.BooleanField()
+    enforce_subaccount_transaction_limits = serializers.BooleanField()
+
+
+class SubAccountTransactionLimitOutSerializer(serializers.ModelSerializer):
+    sub_account = serializers.IntegerField(source="sub_account.id", read_only=True)
+    currency_code = serializers.CharField(source="currency.code", read_only=True)
+
+    class Meta:
+        model = SubAccountTransactionLimit
+        fields = [
+            "id",
+            "sub_account",
+            "currency",
+            "currency_code",
+            "single_limit",
+            "daily_limit",
+        ]
+
+
+class SubAccountTransactionLimitDetailOutSerializer(SubAccountTransactionLimitOutSerializer):
+    sub_account_name = serializers.CharField(source="sub_account.get_full_name", read_only=True)
+    created_at = serializers.DateTimeField(read_only=True)
+    updated_at = serializers.DateTimeField(read_only=True)
+
+    class Meta(SubAccountTransactionLimitOutSerializer.Meta):
+        fields = SubAccountTransactionLimitOutSerializer.Meta.fields + [
+            "sub_account_name",
+            "created_at",
+            "updated_at",
+        ]
+
+
+class SubAccountTransactionLimitSetResponseSerializer(serializers.Serializer):
+    message = serializers.CharField()
+    data = SubAccountTransactionLimitOutSerializer(many=True)
+
+
+class SubAccountTransactionLimitListResponseSerializer(serializers.Serializer):
+    message = serializers.CharField()
+    data = SubAccountTransactionLimitDetailOutSerializer(many=True)
+
+
+class SubAccountGetTransactionLimitSerializer(serializers.Serializer):
+    def validate(self, attrs):
+        request = self.context["request"]
+        if request.user.profile.parent:
+            raise serializers.ValidationError(
+                {"detail": "Only admin can access this resource."}
+            )
+        return attrs
+
+    def get_limits_queryset(self):
+        request = self.context["request"]
+        sub_account_id = self.context["sub_account_id"]
+        return SubAccountTransactionLimit.objects.filter(
+            sub_account_id=sub_account_id,
+            business__user_account_type__user=request.user,
+        ).select_related("currency", "sub_account")
+
+
+class SubAccountLimitPrefillQuerySerializer(serializers.Serializer):
+    email = serializers.EmailField()
+
+    def validate(self, attrs):
+        request = self.context["request"]
+        User = get_user_model()
+
+        try:
+            sub_account = User.objects.get(email=attrs["email"])
+        except User.DoesNotExist:
+            raise serializers.ValidationError({"detail": "Invalid sub account"})
+
+        user_account_type = UserAccountType.objects.filter(
+            user=request.user,
+            account_type__name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER,
+        ).first()
+        if not user_account_type or not user_account_type.business:
+            raise serializers.ValidationError({"detail": "Business not found"})
+
+        business = user_account_type.business
+        if not SubAccountPermission.objects.filter(
+            sub_account=sub_account,
+            business=business,
+        ).exists():
+            raise serializers.ValidationError({
+                "detail": "User is not a sub-account of this business"
+            })
+
+        account_type = request.user.profile.account_type
+        if not account_type:
+            raise serializers.ValidationError({
+                "detail": "Business account type is not configured"
+            })
+
+        attrs["sub_account"] = sub_account
+        attrs["business"] = business
+        attrs["account_type"] = account_type
+        return attrs
+
+    def build_prefill_payload(self):
+        sub_account = self.validated_data["sub_account"]
+        business = self.validated_data["business"]
+        account_type = self.validated_data["account_type"]
+        request = self.context["request"]
+
+        is_verified = request.user.profile.is_verified()
+        
+        currencies = []
+        for code in ["NGN", "CAD", "USD"]:
+            currency = Currency.objects.filter(code=code).first()
+            if not currency:
+                continue
+
+            org_limit = CurrencyTransactionLimit.get_resolved_limit(
+                account_type=account_type,
+                for_verified_user=is_verified,
+                currency=currency,
+            )
+
+            saved_limit = SubAccountTransactionLimit.objects.filter(
+                sub_account=sub_account,
+                business=business,
+                currency=currency,
+            ).first()
+
+            currencies.append(
+                {
+                    "code": code,
+                    "currency_id": currency.id,
+                    "org_single_cap": str(org_limit.max_single_external_transfer_amount),
+                    "org_daily_cap": str(org_limit.max_daily_external_transfer_amount),
+                    "default_single_limit": str(
+                        org_limit.max_single_external_transfer_amount / 2
+                    ),
+                    "default_daily_limit": str(
+                        org_limit.max_daily_external_transfer_amount / 2
+                    ),
+                    "saved_single_limit": (
+                        str(saved_limit.single_limit) if saved_limit else None
+                    ),
+                    "saved_daily_limit": (
+                        str(saved_limit.daily_limit) if saved_limit else None
+                    ),
+                }
+            )
+
+        return {
+            "sub_account": sub_account.email,
+            "currencies": currencies,
+        }
+
+
+class SubAccountLimitPrefillCurrencySerializer(serializers.Serializer):
+    code = serializers.CharField()
+    currency_id = serializers.IntegerField()
+    org_single_cap = serializers.CharField()
+    org_daily_cap = serializers.CharField()
+    default_single_limit = serializers.CharField()
+    default_daily_limit = serializers.CharField()
+    saved_single_limit = serializers.CharField(allow_null=True)
+    saved_daily_limit = serializers.CharField(allow_null=True)
+
+
+class SubAccountLimitPrefillResponseSerializer(serializers.Serializer):
+    sub_account = serializers.EmailField()
+    currencies = SubAccountLimitPrefillCurrencySerializer(many=True)
+
+
+class RequestRBATransactionOTPSerializer(serializers.Serializer):
+    amount = serializers.DecimalField(max_digits=20, decimal_places=2, min_value=Decimal("0.01"))
+    currency = serializers.CharField(max_length=3, min_length=3)
+    recipient = serializers.CharField(max_length=255)
+
+    def validate_currency(self, value):
+        code = value.strip().upper()
+        currency = Currency.objects.filter(code__iexact=code, active=True).first()
+        if not currency:
+            raise serializers.ValidationError("Invalid or inactive currency code.")
+        return currency
+
+    def validate(self, attrs):
+        request = self.context["request"]
+        user = request.user
+
+        if not getattr(user, "profile", None) or not user.profile.parent:
+            raise serializers.ValidationError({
+                "detail": "Transaction authorization request only applies to sub-accounts"
+            })
+
+        parent_user = user.profile.parent.user
+        account = UserAccountType.objects.filter(
+            user=parent_user,
+            account_type__name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER,
+        ).first()
+        if not account or not account.business:
+            raise serializers.ValidationError({"detail": "Business not found"})
+
+        business = account.business
+        if not business.rba_transaction_otp:
+            raise serializers.ValidationError({
+                "detail": "OTP is disabled for this organization"
+            })
+
+        attrs["user"] = user
+        attrs["business"] = business
+        attrs["parent_user"] = parent_user
+        return attrs
+
+    def save(self, **kwargs):
+        user = self.validated_data["user"]
+        business = self.validated_data["business"]
+        parent_user = self.validated_data["parent_user"]
+        amount = self.validated_data["amount"]
+        currency = self.validated_data["currency"]
+        recipient = self.validated_data["recipient"]
+        otp_expiry_minutes = settings.RBA_TRANSACTION_OTP_EXPIRY_MINUTES
+
+        sub_account_name = user.get_full_name().strip() or user.email
+        business_name = business.name or get_business_name(parent_user.id)
+        initiated_at = timezone.localtime(timezone.now()).strftime("%d/%m/%Y %I:%M%p")
+        formatted_amount = f"{amount.quantize(Decimal('0.01')):,.2f}"
+
+        otp_code = f"{uuid.uuid4().int % 1000000:06d}"
+        SubAccountTransactionAuthorization.objects.create(
+            user=user,
+            business=business,
+            currency=currency,
+            amount=amount,
+            otp=otp_code,
+            expires_at=timezone.now() + timedelta(minutes=otp_expiry_minutes),
+        )
+        send_rba_transaction_approval_otp_email.delay(
+            parent_user_id=parent_user.id,
+            otp_code=otp_code,
+            business_name=business_name,
+            sub_account_name=sub_account_name,
+            amount=formatted_amount,
+            currency=currency.code,
+            recipient=recipient,
+            initiated_at=initiated_at,
+            expiry_minutes=otp_expiry_minutes,
+        )
+        return {"detail": "OTP sent successfully"}
+
+
+class RequestRBATransactionOTPResponseSerializer(serializers.Serializer):
+    detail = serializers.CharField()
+
+
+class ValidateRBATransactionOTPSerializer(serializers.Serializer):
+    otp = serializers.CharField(max_length=6)
+    amount = serializers.DecimalField(max_digits=20, decimal_places=2, min_value=Decimal("0.01"))
+    currency = serializers.CharField(max_length=3, min_length=3)
+
+    def validate_currency(self, value):
+        code = value.strip().upper()
+        currency = Currency.objects.filter(code__iexact=code, active=True).first()
+        if not currency:
+            raise serializers.ValidationError("Invalid or inactive currency code.")
+        return currency
+
+    def validate(self, attrs):
+        request = self.context["request"]
+        user = request.user
+
+        if not getattr(user, "profile", None) or not user.profile.parent:
+            raise serializers.ValidationError({
+                "detail": "Transaction OTP validation applies to sub-accounts only"
+            })
+
+        parent_user = user.profile.parent.user
+        account = UserAccountType.objects.filter(
+            user=parent_user,
+            account_type__name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER,
+        ).first()
+        if not account or not account.business:
+            raise serializers.ValidationError({"detail": "Business not found"})
+
+        otp_obj = SubAccountTransactionAuthorization.objects.filter(
+            user=user,
+            business=account.business,
+            currency=attrs["currency"],
+            amount=attrs["amount"],
+            otp=attrs["otp"],
+            is_used=False,
+        ).order_by("-created_at").first()
+
+        if not otp_obj:
+            raise serializers.ValidationError({"detail": "No valid OTP request found"})
+
+        if otp_obj.is_expired():
+            raise serializers.ValidationError({"detail": "OTP expired"})
+
+        attrs["otp_obj"] = otp_obj
+        return attrs
+
+    def save(self, **kwargs):
+        self.validated_data["otp_obj"].mark_as_used()
+        return {"detail": "OTP validated successfully"}
+
+
+class ValidateRBATransactionOTPResponseSerializer(serializers.Serializer):
+    detail = serializers.CharField()
+class PayrollSummaryQuerySerializer(serializers.Serializer):
+    period = serializers.CharField(
+        required=False,
+        allow_blank=True,
+        help_text="Period identifier (e.g. '2024-01', 'October 2025'). If period_end is provided, this acts as the start period.",
+    )
+    period_end = serializers.CharField(
+        required=False,
+        allow_blank=True,
+        help_text="End period identifier for range filtering (e.g. '2024-05')",
+    )
+    month = serializers.CharField(
+        required=False,
+        allow_blank=True,
+        help_text="Month name (e.g. 'January')",
+    )
+    year = serializers.IntegerField(
+        required=False,
+        help_text="Year (e.g. 2024)",
+    )
+
+    def validate(self, attrs):
+        return {
+            key: value
+            for key, value in attrs.items()
+            if value not in ("", None)
+        }
+
+    @property
+    def filters(self):
+        return {
+            "period": self.validated_data.get("period"),
+            "period_end": self.validated_data.get("period_end"),
+            "month": self.validated_data.get("month"),
+            "year": self.validated_data.get("year"),
+        }
+
+    def get_cache_key(self, business_id):
+        filters = self.filters
+        return (
+            f"payroll_summary_{business_id}_"
+            f"{filters['period'] or 'none'}_"
+            f"{filters['period_end'] or 'none'}_"
+            f"{filters['month'] or 'none'}_"
+            f"{filters['year'] or 'none'}"
+        )
 
 
+class PayrollSummarySerializerOut(serializers.Serializer):
+    employees_paid = serializers.IntegerField(help_text="Number of employees paid in this period")
+    employees_pending = serializers.IntegerField(help_text="Number of employees pending payment in this period")
+    total_disbursed = serializers.DictField(child=serializers.DecimalField(max_digits=100, decimal_places=2), help_text="Total amount disbursed grouped by currency code")
+    past_periods = serializers.ListField(child=serializers.CharField(), help_text="List of past period identifiers")
 
diff --git a/v2/business_management/efb/services/__init__.py b/v2/business_management/efb/services/__init__.py
new file mode 100644
index 000000000..ccf8640cb
--- /dev/null
+++ b/v2/business_management/efb/services/__init__.py
@@ -0,0 +1 @@
+from .payroll import get_payroll_summary
\ No newline at end of file
diff --git a/v2/business_management/efb/services/payroll.py b/v2/business_management/efb/services/payroll.py
new file mode 100644
index 000000000..d671db888
--- /dev/null
+++ b/v2/business_management/efb/services/payroll.py
@@ -0,0 +1,52 @@
+from decimal import Decimal
+from django.db.models import Sum
+from v2.business_management.efb.models import Employee, PaidSalary
+
+
+def get_payroll_summary(user, business_id, period=None, period_end=None, month=None, year=None):
+    paid_salaries = PaidSalary.objects.filter(user=user)
+
+    if not period and not month and not year:
+        latest_salary = PaidSalary.objects.filter(user=user).order_by("-date_created").first()
+        if latest_salary:
+            period = latest_salary.period
+            year = latest_salary.date_created.year
+
+    if period and period_end:
+        paid_salaries = paid_salaries.filter(period__gte=period, period__lte=period_end)
+    elif period:
+        paid_salaries = paid_salaries.filter(period=period)
+
+    if month:
+        paid_salaries = paid_salaries.filter(period=month)
+    if year:
+        paid_salaries = paid_salaries.filter(date_created__year=year)
+
+    paid_employee_ids = set(paid_salaries.values_list("employee_id", flat=True))
+    employees_paid_count = len(paid_employee_ids)
+
+    disbursements = paid_salaries.values("currency__code").annotate(total_amount=Sum("salary"))
+    total_disbursed = {
+        item["currency__code"]: item["total_amount"]
+        for item in disbursements if item["currency__code"]
+    }
+
+    employees = Employee.objects.filter(user=user)
+    employees_pending_count = (
+        employees.exclude(employee_id__in=paid_employee_ids).count()
+        if paid_employee_ids else employees.count()
+    )
+
+    past_periods = list(
+        PaidSalary.objects.filter(user=user)
+        .values_list("period", flat=True)
+        .distinct()
+    )
+    past_periods = [p for p in past_periods if p]
+
+    return {
+        "employees_paid": employees_paid_count,
+        "employees_pending": employees_pending_count,
+        "total_disbursed": total_disbursed,
+        "past_periods": past_periods,
+    }
diff --git a/v2/business_management/efb/tasks.py b/v2/business_management/efb/tasks.py
index 6a8bd5a2a..e63b1a549 100644
--- a/v2/business_management/efb/tasks.py
+++ b/v2/business_management/efb/tasks.py
@@ -687,14 +687,7 @@ def sub_account_invitation_email(name, email, activation_link):
     content = (
         f"Hi {name},<br><br>"
         "You've been granted access to <strong>Expedier for Business</strong>.<br><br>"
-
         "To get started, please activate your account by clicking the link below:<br><br>"
-
-        f"<a href='{activation_link}' "
-        "style='color:#1a73e8; text-decoration:none; font-weight:600;'>"
-        "Accept yYour Invitation</a><br><br>"
-
-
         f"""
         <a href="{activation_link}"
         style="
@@ -711,24 +704,15 @@ def sub_account_invitation_email(name, email, activation_link):
         </a>
         <br><br>
         """
-
-        f"<a href='{activation_link}' "
-        "style='color:#1a73e8; text-decoration:none; font-weight:600;'>"
-        "Accept Your Invitation</a><br><br>"
-
-
         "Once activated, you'll be able to access the tools and permissions assigned to you.<br><br>"
-
         "If you weren't expecting this invitation, please ignore this email or contact our support team.<br><br>"
-
         "Welcome to Expedier!<br><br>"
     )
 
     notification_provider.send(
         to=email,
-        subject=f"You've Been Invited to Expedier for Business",
+        subject="You've Been Invited to Expedier for Business",
         message=content,
-
     )
 
 
diff --git a/v2/business_management/efb/tests.py b/v2/business_management/efb/tests.py
index 7d2ab2343..b7a04404e 100644
--- a/v2/business_management/efb/tests.py
+++ b/v2/business_management/efb/tests.py
@@ -41,6 +41,7 @@ from account.models import (
 from wallet.models import Wallet
 from location.models import Country
 from currency.models import Currency, ExchangeRate
+from currency.models import CurrencyTransactionLimit
 from transaction.models import Transaction
 from factories.base import (
     FileFactory, CurrencyFactory,
@@ -54,7 +55,9 @@ from v2.business_management.efb.serializers import (
 )
 from v2.business_management.efb.models import (
     BusinessSubscriptionPlan, BusinessSubscriptionHistory, SubscriptionPlan, 
-    Invoice, ExpedierForBusiness, Employee
+    Invoice, ExpedierForBusiness, Employee, SubAccountPermission,
+    SubAccountTransactionLimit, SubAccountTransactionAuthorization, PaidSalary, Currency,
+    EFBSubAccountInvitation,
 )
 from v2.business_management.services import ExpedierBusinessCreation
 from .tasks import auto_renew_subscriptions
@@ -72,7 +75,14 @@ from v2.business_management.efb.models import SubAccountPermission
 
 
 from v2.business_management.efb.tasks import sub_account_acceptance_email
+from v2.user_management.efb_subaccounts import SubAccountLimitService
 
+from decimal import Decimal
+from django.test import TestCase
+from django.contrib.auth import get_user_model
+from django.utils import timezone
+
+from v2.business_management.efb.services import get_payroll_summary
 
 class ExternalUserAccountTypeVerificationTests(APITestCase):
     def setUp(self):
@@ -2007,6 +2017,232 @@ class SubAccountStatusUpdateViewTest(APITestCase):
         ])
 
 
+class EFBSubaccountProcessorRemoveTest(TestCase):
+
+    def setUp(self):
+        self.admin = User.objects.create_user(
+            username="admin",
+            email="admin@test.com",
+            password="password123",
+            is_active=True,
+        )
+        self.sub_user = User.objects.create_user(
+            username="sub",
+            email="sub@test.com",
+            password="password123",
+            is_active=True,
+        )
+        self.admin_profile = Profile.objects.create(user=self.admin)
+        self.sub_profile = Profile.objects.create(user=self.sub_user, parent=self.admin_profile)
+
+        self.user_account_type = UserAccountType.objects.create(
+            user=self.admin,
+            name="Test Business",
+        )
+        self.business = ExpedierForBusiness.objects.create(
+            name="Test Business",
+            user_account_type=self.user_account_type,
+        )
+        self.permission = SubAccountPermission.objects.create(
+            sub_account=self.sub_user,
+            business=self.business,
+            status="active",
+            can_view_transactions=True,
+        )
+        EFBSubAccountInvitation.objects.create(
+            email=self.sub_user.email,
+            name="Sub User",
+            invited_by=self.admin,
+            status="active",
+            is_accepted=True,
+            expires_at=timezone.now() + timedelta(days=30),
+        )
+
+    def test_remove_subaccount_success(self):
+        from v2.user_management.efb_subaccounts import EFBSubaccountProcessor
+
+        EFBSubaccountProcessor.remove_subaccount(
+            requested_by=self.admin,
+            email=self.sub_user.email,
+        )
+
+        self.permission.refresh_from_db()
+        self.sub_user.refresh_from_db()
+        self.sub_profile.refresh_from_db()
+        invitation = EFBSubAccountInvitation.objects.get(email=self.sub_user.email)
+
+        self.assertEqual(self.permission.status, "removed")
+        self.assertFalse(self.permission.can_view_transactions)
+        self.assertFalse(self.sub_user.is_active)
+        self.assertFalse(self.sub_profile.active)
+        self.assertEqual(invitation.status, "removed")
+        self.assertIsNotNone(self.sub_profile.parent_id)
+
+    def test_remove_subaccount_not_found(self):
+        from v2.user_management.efb_subaccounts import (
+            EFBSubaccountProcessor,
+            SUBACCOUNT_NOT_FOUND_MESSAGE,
+        )
+
+        with self.assertRaisesMessage(ValueError, SUBACCOUNT_NOT_FOUND_MESSAGE):
+            EFBSubaccountProcessor.remove_subaccount(
+                requested_by=self.admin,
+                email="missing@test.com",
+            )
+
+    def test_remove_subaccount_forbidden_for_subaccount_actor(self):
+        from rest_framework.exceptions import PermissionDenied
+        from v2.user_management.efb_subaccounts import EFBSubaccountProcessor
+
+        with self.assertRaises(PermissionDenied):
+            EFBSubaccountProcessor.remove_subaccount(
+                requested_by=self.sub_user,
+                email="other@test.com",
+            )
+
+    def test_remove_pending_invitation(self):
+        from v2.user_management.efb_subaccounts import EFBSubaccountProcessor
+
+        invitation = EFBSubAccountInvitation.objects.create(
+            email="pending@test.com",
+            name="Pending User",
+            invited_by=self.admin,
+            status="pending",
+            is_accepted=False,
+            expires_at=timezone.now() + timedelta(days=30),
+        )
+
+        EFBSubaccountProcessor.remove_subaccount(
+            requested_by=self.admin,
+            email=invitation.email,
+        )
+
+        invitation.refresh_from_db()
+        self.assertEqual(invitation.status, "removed")
+
+    def test_remove_deactivated_pending_invitation(self):
+        from v2.user_management.efb_subaccounts import EFBSubaccountProcessor
+
+        invitation = EFBSubAccountInvitation.objects.create(
+            email="deactivated-pending@test.com",
+            name="Deactivated Pending",
+            invited_by=self.admin,
+            status="deactivated",
+            is_accepted=False,
+            expires_at=timezone.now() + timedelta(days=30),
+        )
+
+        EFBSubaccountProcessor.remove_subaccount(
+            requested_by=self.admin,
+            email=invitation.email,
+        )
+
+        invitation.refresh_from_db()
+        self.assertEqual(invitation.status, "removed")
+
+    def test_remove_subaccount_already_removed(self):
+        from v2.user_management.efb_subaccounts import (
+            EFBSubaccountProcessor,
+            SUBACCOUNT_NOT_FOUND_MESSAGE,
+        )
+
+        self.permission.status = "removed"
+        self.permission.save(update_fields=["status"])
+
+        with self.assertRaisesMessage(ValueError, SUBACCOUNT_NOT_FOUND_MESSAGE):
+            EFBSubaccountProcessor.remove_subaccount(
+                requested_by=self.admin,
+                email=self.sub_user.email,
+            )
+
+    def test_remove_subaccount_without_business(self):
+        from v2.user_management.efb_subaccounts import EFBSubaccountProcessor
+
+        admin_without_business = User.objects.create_user(
+            username="nobiz",
+            email="nobiz@test.com",
+            password="password123",
+            is_active=True,
+        )
+        Profile.objects.create(user=admin_without_business)
+        UserAccountType.objects.create(user=admin_without_business, name="No Business Org")
+
+        with self.assertRaisesMessage(ValueError, "Your organization details not found"):
+            EFBSubaccountProcessor.remove_subaccount(
+                requested_by=admin_without_business,
+                email=self.sub_user.email,
+            )
+
+    def test_set_subaccount_status_blocked_for_removed(self):
+        from v2.user_management.efb_subaccounts import EFBSubaccountProcessor
+
+        self.permission.status = "removed"
+        self.permission.save(update_fields=["status"])
+
+        with self.assertRaisesMessage(
+            ValueError,
+            "Sub-account was removed. Re-invite them to restore access.",
+        ):
+            EFBSubaccountProcessor.set_subaccount_status(
+                requested_by=self.admin,
+                email=self.sub_user.email,
+                is_active=True,
+                status="active",
+            )
+
+
+class SubAccountRemoveViewTest(APITestCase):
+
+    def setUp(self):
+        self.client = APIClient()
+        self.admin = User.objects.create_user(
+            username="admin",
+            email="admin@test.com",
+            password="password123",
+            is_active=True,
+        )
+        Profile.objects.create(user=self.admin)
+        self.client.force_authenticate(user=self.admin)
+        self.url = reverse("Expedier-For-Business:subaccount-permissions-admin")
+
+    @patch("v2.business_management.efb.views.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.views.EFBSubaccountProcessor.remove_subaccount")
+    def test_remove_subaccount_success(self, mock_remove, mock_permission):
+        mock_remove.return_value = MagicMock()
+
+        response = self.client.delete(
+            self.url,
+            {"email": "sub@test.com"},
+            format="json",
+        )
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        self.assertEqual(response.data["detail"], "Sub-account removed successfully.")
+
+    @patch("v2.business_management.efb.views.IsValidatedEFBUser.has_permission", return_value=True)
+    def test_remove_subaccount_missing_email(self, mock_permission):
+        response = self.client.delete(self.url, {}, format="json")
+
+        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
+        self.assertIn("email", response.data)
+
+    @patch("v2.business_management.efb.views.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.views.EFBSubaccountProcessor.remove_subaccount")
+    def test_remove_subaccount_not_found(self, mock_remove, mock_permission):
+        from v2.user_management.efb_subaccounts import SUBACCOUNT_NOT_FOUND_MESSAGE
+
+        mock_remove.side_effect = ValueError(SUBACCOUNT_NOT_FOUND_MESSAGE)
+
+        response = self.client.delete(
+            self.url,
+            {"email": "missing@test.com"},
+            format="json",
+        )
+
+        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
+        self.assertEqual(response.data["detail"], SUBACCOUNT_NOT_FOUND_MESSAGE)
+
+
 class SubAccountAcceptanceEmailTest(TestCase):
 
     @patch("v2.business_management.efb.tasks.EmailNotification")
@@ -2051,4 +2287,389 @@ class SubscriptionPlanSerializationTest(TestCase):
         self.assertIsNone(data["plan"]["currency_code"])
 
 
+class SubAccountTransactionLimitEndpointsTest(APITestCase):
+    def setUp(self):
+        self.client = APIClient()
+        self.admin_user = User.objects.create_user(
+            username="admin_limit",
+            email="admin_limit@test.com",
+            password="password123",
+        )
+        self.sub_account_user = User.objects.create_user(
+            username="sub_limit",
+            email="sub_limit@test.com",
+            password="password123",
+        )
+
+        self.admin_profile = Profile.objects.create(user=self.admin_user)
+        self.sub_profile = Profile.objects.create(
+            user=self.sub_account_user,
+            parent=self.admin_profile,
+        )
+
+        self.account_type = AccountType.objects.create(
+            name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER
+        )
+        self.admin_profile.account_type = self.account_type
+        self.admin_profile.save(update_fields=["account_type"])
+
+        self.parent_account = UserAccountType.objects.create(
+            user=self.admin_user,
+            account_type=self.account_type,
+        )
+        UserAccountType.objects.create(
+            user=self.sub_account_user,
+            account_type=self.account_type,
+        )
+
+        self.business = ExpedierForBusiness.objects.create(
+            user_account_type=self.parent_account,
+            name="Limit Biz",
+        )
+        SubAccountPermission.objects.create(
+            sub_account=self.sub_account_user,
+            business=self.business,
+        )
+
+        self.currency = Currency.objects.create(code="USD", name="US Dollar", symbol="$")
+        self.currency_ngn = Currency.objects.create(code="NGN", name="Naira", symbol="N")
+        self.currency_cad = Currency.objects.create(code="CAD", name="Canadian Dollar", symbol="C$")
+        CurrencyTransactionLimit.objects.create(
+            account_type=self.account_type,
+            currency=self.currency,
+            for_verified_user=False,
+            max_single_external_transfer_amount=Decimal("100000.00"),
+            max_daily_external_transfer_amount=Decimal("100000.00"),
+            active=True,
+        )
+        CurrencyTransactionLimit.objects.create(
+            account_type=self.account_type,
+            currency=self.currency_ngn,
+            for_verified_user=False,
+            max_single_external_transfer_amount=Decimal("200000.00"),
+            max_daily_external_transfer_amount=Decimal("300000.00"),
+            active=True,
+        )
+        CurrencyTransactionLimit.objects.create(
+            account_type=self.account_type,
+            currency=self.currency_cad,
+            for_verified_user=False,
+            max_single_external_transfer_amount=Decimal("400000.00"),
+            max_daily_external_transfer_amount=Decimal("500000.00"),
+            active=True,
+        )
+
+        self.set_limit_url = reverse("Expedier-For-Business:set-limit")
+        self.get_limit_url = reverse(
+            "Expedier-For-Business:get-limit",
+            kwargs={"id": self.sub_account_user.id},
+        )
+        self.prefill_url = reverse("Expedier-For-Business:get-limit-prefill")
+        self.set_auth_url = reverse("Expedier-For-Business:set-transaction-auth")
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_set_sub_account_transaction_limit_success(self, mock_effective_permission, mock_validated_permission):
+        self.client.force_authenticate(user=self.admin_user)
+        payload = {
+            "email": self.sub_account_user.email,
+            "limits": [
+                {
+                    "currency": self.currency.id,
+                    "single_limit": "5000.00",
+                    "daily_limit": "20000.00",
+                }
+            ],
+        }
+
+        response = self.client.post(self.set_limit_url, payload, format="json")
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        self.assertEqual(response.data["message"], "Transaction limits set successfully")
+        self.assertEqual(len(response.data["data"]), 1)
+        self.assertTrue(
+            SubAccountTransactionLimit.objects.filter(
+                sub_account=self.sub_account_user,
+                business=self.business,
+                currency=self.currency,
+            ).exists()
+        )
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_get_sub_account_transaction_limit_list_success(self, mock_effective_permission, mock_validated_permission):
+        self.client.force_authenticate(user=self.admin_user)
+        SubAccountTransactionLimit.objects.create(
+            sub_account=self.sub_account_user,
+            business=self.business,
+            currency=self.currency,
+            single_limit=Decimal("5000.00"),
+            daily_limit=Decimal("20000.00"),
+        )
+
+        response = self.client.get(self.get_limit_url)
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        self.assertEqual(response.data["message"], "Transaction limits retrieved successfully")
+        self.assertEqual(len(response.data["data"]), 1)
+        self.assertEqual(response.data["data"][0]["currency_code"], "USD")
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_toggle_rba_transaction_otp_setting(self, mock_effective_permission, mock_validated_permission):
+        self.client.force_authenticate(user=self.admin_user)
+
+        response = self.client.put(
+            self.set_auth_url,
+            {"rba_transaction_otp": True},
+            format="json",
+        )
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        self.assertEqual(
+            response.data["detail"],
+            "RBA transaction authorization settings updated successfully",
+        )
+        self.assertTrue(response.data["rba_transaction_otp"])
+        self.assertFalse(response.data["enforce_subaccount_transaction_limits"])
+        self.business.refresh_from_db()
+        self.assertTrue(self.business.rba_transaction_otp)
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_toggle_enforce_subaccount_transaction_limits(self, mock_effective_permission, mock_validated_permission):
+        self.client.force_authenticate(user=self.admin_user)
+
+        response = self.client.put(
+            self.set_auth_url,
+            {"enforce_subaccount_transaction_limits": True},
+            format="json",
+        )
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        self.assertTrue(response.data["enforce_subaccount_transaction_limits"])
+        self.business.refresh_from_db()
+        self.assertTrue(self.business.enforce_subaccount_transaction_limits)
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_set_auth_requires_at_least_one_setting(self, mock_effective_permission, mock_validated_permission):
+        self.client.force_authenticate(user=self.admin_user)
+
+        response = self.client.put(self.set_auth_url, {}, format="json")
+
+        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
+        self.assertEqual(response.data["detail"], "No settings provided to update")
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_sub_account_limit_validation_skipped_when_enforcement_off(
+        self,
+        mock_effective_permission,
+        mock_validated_permission,
+    ):
+        request = APIRequestFactory().post(
+            "/transaction/send-funds",
+            {"amount": "1000.00"},
+            format="json",
+        )
+        request.logged_in_user = self.sub_account_user
+
+        context = SubAccountLimitService.validate(
+            request=request,
+            currency=self.currency,
+            amount=Decimal("1000.00"),
+        )
+
+        self.assertIsNone(context)
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    @patch("v2.business_management.efb.permissions.EffectiveUserPermission.has_permission", return_value=True)
+    def test_get_sub_account_limit_prefill_returns_org_caps_and_defaults(self, mock_effective_permission, mock_validated_permission):
+        self.client.force_authenticate(user=self.admin_user)
+        SubAccountTransactionLimit.objects.create(
+            sub_account=self.sub_account_user,
+            business=self.business,
+            currency=self.currency,
+            single_limit=Decimal("1000.00"),
+            daily_limit=Decimal("2000.00"),
+        )
+
+        response = self.client.get(self.prefill_url, {"email": self.sub_account_user.email})
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        self.assertEqual(response.data["sub_account"], self.sub_account_user.email)
+        self.assertEqual(len(response.data["currencies"]), 3)
+
+        usd_payload = next(item for item in response.data["currencies"] if item["code"] == "USD")
+        self.assertEqual(usd_payload["org_single_cap"], "100000.00")
+        self.assertEqual(usd_payload["org_daily_cap"], "100000.00")
+        self.assertEqual(usd_payload["default_single_limit"], "50000.00")
+        self.assertEqual(usd_payload["default_daily_limit"], "50000.00")
+        self.assertEqual(usd_payload["saved_single_limit"], "1000.00")
+        self.assertEqual(usd_payload["saved_daily_limit"], "2000.00")
+
+
+class SubAccountTransactionOtpFlowTest(APITestCase):
+    def setUp(self):
+        self.client = APIClient()
+        self.parent_user = User.objects.create_user(
+            username="otp_parent",
+            email="otp_parent@test.com",
+            password="password123",
+        )
+        self.sub_user = User.objects.create_user(
+            username="otp_sub",
+            email="otp_sub@test.com",
+            password="password123",
+        )
+
+        self.parent_profile = Profile.objects.create(user=self.parent_user)
+        self.sub_profile = Profile.objects.create(user=self.sub_user, parent=self.parent_profile)
+
+        self.account_type = AccountType.objects.create(
+            name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER
+        )
+        self.parent_profile.account_type = self.account_type
+        self.parent_profile.save(update_fields=["account_type"])
+
+        self.parent_account = UserAccountType.objects.create(
+            user=self.parent_user,
+            account_type=self.account_type,
+        )
+        UserAccountType.objects.create(
+            user=self.sub_user,
+            account_type=self.account_type,
+        )
+
+        self.business = ExpedierForBusiness.objects.create(
+            user_account_type=self.parent_account,
+            name="OTP Biz",
+            rba_transaction_otp=True,
+        )
+
+        self.validate_url = reverse("Expedier-For-Business:validate-otp")
+
+    @patch("v2.business_management.efb.permissions.IsValidatedEFBUser.has_permission", return_value=True)
+    def test_validate_otp_marks_record_as_used(self, mock_validated_permission):
+        usd = Currency.objects.create(name="US Dollar", code="USD", symbol="$")
+        otp_record = SubAccountTransactionAuthorization.objects.create(
+            user=self.sub_user,
+            business=self.business,
+            currency=usd,
+            amount=Decimal("500.00"),
+            otp="123456",
+            expires_at=timezone.now() + timedelta(minutes=5),
+            is_used=False,
+        )
+        self.client.force_authenticate(user=self.sub_user)
+
+        response = self.client.post(
+            self.validate_url,
+            {"otp": "123456", "amount": "500.00", "currency": "USD"},
+            format="json",
+        )
+
+        self.assertEqual(response.status_code, status.HTTP_200_OK)
+        otp_record.refresh_from_db()
+        self.assertTrue(otp_record.is_used)
+
+
+
+class TestGetPayrollSummary(TestCase):
+    User = get_user_model()
+
+    def setUp(self):
+        self.user = User.objects.create_user(
+            username="mockuser", email="mock@example.com", password="password"
+        )
+        # Create currencies
+        self.usd = Currency.objects.create(name="US Dollar", code="USD", symbol="$")
+        self.cad = Currency.objects.create(name="Canadian Dollar", code="CAD", symbol="C$")
+        self.ngn = Currency.objects.create(name="Naira", code="NGN", symbol="₦")
+
+        # Create employees
+        self.emp1 = Employee.objects.create(user=self.user, employee_id="EMP-001")
+        self.emp2 = Employee.objects.create(user=self.user, employee_id="EMP-002")
+        self.emp3 = Employee.objects.create(user=self.user, employee_id="EMP-003")
+
+    def test_current_period_summary(self):
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-001",
+            salary=Decimal("4500.00"), currency=self.usd,
+            period="2026-05", date_created=timezone.now()
+        )
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-002",
+            salary=Decimal("3800.00"), currency=self.cad,
+            period="2026-05", date_created=timezone.now()
+        )
+
+        summary = get_payroll_summary(user=self.user, business_id=1, period="2026-05")
+        self.assertEqual(summary["employees_paid"], 2)
+        self.assertEqual(summary["employees_pending"], 1)
+        self.assertEqual(summary["total_disbursed"]["USD"], Decimal("4500.00"))
+        self.assertEqual(summary["total_disbursed"]["CAD"], Decimal("3800.00"))
+
+    def test_multi_currency_totals(self):
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-001",
+            salary=Decimal("1000.00"), currency=self.usd,
+            period="2026-05", date_created=timezone.now()
+        )
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-001",
+            salary=Decimal("2000.00"), currency=self.cad,
+            period="2026-05", date_created=timezone.now()
+        )
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-001",
+            salary=Decimal("3000.00"), currency=self.ngn,
+            period="2026-05", date_created=timezone.now()
+        )
+
+        summary = get_payroll_summary(user=self.user, business_id=1, period="2026-05")
+        self.assertEqual(summary["total_disbursed"]["USD"], Decimal("1000.00"))
+        self.assertEqual(summary["total_disbursed"]["CAD"], Decimal("2000.00"))
+        self.assertEqual(summary["total_disbursed"]["NGN"], Decimal("3000.00"))
+
+    def test_range_query(self):
+        for month in ["2026-01", "2026-02", "2026-03"]:
+            PaidSalary.objects.create(
+                user=self.user, employee_id="EMP-001",
+                salary=Decimal("1000.00"), currency=self.usd,
+                period=month, date_created=timezone.now()
+            )
+
+        summary = get_payroll_summary(user=self.user, business_id=1,
+                                      period="2026-01", period_end="2026-03")
+        self.assertTrue(all(p in summary["past_periods"] for p in ["2026-01","2026-02","2026-03"]))
+
+    def test_month_year_filter(self):
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-001",
+            salary=Decimal("1000.00"), currency=self.usd,
+            period="May", date_created=timezone.datetime(2026, 5, 1, tzinfo=timezone.utc)
+        )
+
+        summary = get_payroll_summary(user=self.user, business_id=1, month="May", year=2026)
+        self.assertEqual(summary["employees_paid"], 1)
+
+    def test_no_period(self):
+        PaidSalary.objects.create(
+            user=self.user, employee_id="EMP-001",
+            salary=Decimal("1000.00"), currency=self.usd,
+            period="2026-04", date_created=timezone.now()
+        )
+
+        summary = get_payroll_summary(user=self.user, business_id=1)
+        self.assertIn("employees_paid", summary)
+        self.assertIn("employees_pending", summary)
+
+    def test_all_pending(self):
+        summary = get_payroll_summary(user=self.user, business_id=1, period="2026-06")
+        self.assertEqual(summary["employees_paid"], 0)
+        self.assertEqual(summary["employees_pending"], 3)
+
+
 
diff --git a/v2/business_management/efb/urls.py b/v2/business_management/efb/urls.py
index ad0428a44..21bb187b6 100644
--- a/v2/business_management/efb/urls.py
+++ b/v2/business_management/efb/urls.py
@@ -41,6 +41,7 @@ efb_patterns = [
     path("business/create-invoice", views.InvoiceViewsets.as_view({'post': 'create_invoice'}), name='create-invoice'),
     path("business/invoices", views.InvoiceViewsets.as_view({'get': 'invoices'}), name='get-invoices'),
     path("business/update-invoice/<str:invoice_id>", views.InvoiceViewsets.as_view({'put': 'update_invoice'}), name='update-invoices'),
+    path("business/set-transaction-auth", views.SetRBATransactionAuthorizationView.as_view(), name="set-transaction-auth"),
 
     path("business/default-invoice-details", views.InvoiceViewsets.as_view({'get': 'default_invoice_details'}), name='get_details'),
     path("business/generate-pdf-invoice/<str:invoice_id>/", views.InvoiceViewsets.as_view({'get': 'generate_pdf'}), name='invoice_pdf_view'),
@@ -52,6 +53,7 @@ efb_patterns = [
     path("business/delete-employee", views.EmployeeViewSets.as_view({'delete': 'delete_employee'}), name='employee-delete'),
     path("business/pay-salary", views.PaySalaryViewSets.as_view({'post': 'create'}), name='pay'),
     path("business/pay-slip", views.PaySalaryViewSets.as_view({'get': 'pay_slip'}), name='slip'),
+    path("business/<int:business_id>/payroll-summary/", views.PayrollSummaryAPIView.as_view(), name='payroll-summary'),
     path("business/subscription-plans", views.SubscriptionViewSets.as_view({'get': 'sub_plans'}), name='plans'),
     path("business/subscribe", views.SubscriptionViewSets.as_view({'post': 'subscribe'}), name='sub'),
     path("business/change-billing-cycle", views.SubscriptionViewSets.as_view({'post': 'change_billing_cycle'}), name='billing_cycle'),
@@ -63,6 +65,11 @@ efb_patterns = [
     path("business/subaccounts/<int:sub_perm_id>/", views.SubAccountPermissionAdminView.as_view(), name="subaccount-permissions-admin-detail"),
 
     path("business/subaccounts/status", views.SubAccountStatusUpdateView.as_view(), name="status-change"),
+    path("business/subaccounts/get-transaction-limit-prefill", views.SubAccountLimitPrefillView.as_view(), name="get-limit-prefill"),
+    path("business/subaccounts/set-transaction-limit", views.SubAccountSetTransactionLimitView.as_view(), name="set-limit"),
+    path("business/subaccounts/get-transaction-limit/<int:id>/", views.SubAccountGetTransactionLimitListView.as_view(), name="get-limit"),
+    path("business/subaccounts/request-transaction-otp", views.RequestRBATransactionOTPView.as_view(), name="transaction-otp"),
+    path("business/subaccounts/validate-transaction-otp", views.ValidateRBATransactionOTPView.as_view(), name="validate-otp"),
 
 
 ]
diff --git a/v2/business_management/efb/views.py b/v2/business_management/efb/views.py
index ab85274ee..a76afe047 100644
--- a/v2/business_management/efb/views.py
+++ b/v2/business_management/efb/views.py
@@ -2,6 +2,7 @@ import uuid
 import boto3
 import logging
 import json
+from decimal import Decimal
 from typing import Any, Union
 from datetime import timedelta, datetime, timezone as dt_timezone
 from collections import defaultdict
@@ -32,6 +33,7 @@ from rest_framework import viewsets, throttling
 
 from account.models import Currency, User, ExternalUserAccountTypeVerificationFile, ExternalUserAccountTypeVerification, UserAccountType
 from account.utils import handle_exceptions, validate_request_size
+from currency.models import CurrencyTransactionLimit
 from expedier.permissions import extra_headers
 
 
@@ -51,7 +53,21 @@ from v2.business_management.efb.serializers import (
     BusinessWalletCreationSerializerIn, BusinessWalletCreationSerializerOut,
     TransactionsSerializerOut, WebRecentTransactionsSerializerOut, ChangeBillingCycleSerializer,
     GroupedSubscriptionPlansSerializer, SubAccountInvitationSerializer, SubAccountInviteRequestSerializer,
-    SubAccountSerializer, SubAccountPermissionUpdateSerializer, PendingSubAccountSerializer
+    SubAccountRemoveRequestSerializer, SubAccountRemoveResponseSerializer,
+    SubAccountSerializer, SubAccountPermissionUpdateSerializer, PendingSubAccountSerializer,
+    PayrollSummaryQuerySerializer, PayrollSummarySerializerOut,
+    SubAccountTransactionLimitSerializer,
+    SetRBATransactionAuthorizationSerializer,
+    SetRBATransactionAuthorizationResponseSerializer,
+    SubAccountTransactionLimitSetResponseSerializer,
+    SubAccountGetTransactionLimitSerializer,
+    SubAccountTransactionLimitListResponseSerializer,
+    SubAccountLimitPrefillQuerySerializer,
+    SubAccountLimitPrefillResponseSerializer,
+    RequestRBATransactionOTPSerializer,
+    RequestRBATransactionOTPResponseSerializer,
+    ValidateRBATransactionOTPSerializer,
+    ValidateRBATransactionOTPResponseSerializer,
 )
 from v2.business_management.services import ExpedierBusinessCreation
 from v2.business_management.efb.filters import query_params, payslip_parameters
@@ -59,7 +75,8 @@ from v2.business_management.efb.models import (
     InvoiceItem, ExpedierForBusiness,
     SubscriptionPlan, BusinessOwner,
     Invoice, Employee, PaidSalary, ZohoSignWebhookEvent,
-    BusinessSubscriptionPlan, SubAccountPermission, EFBSubAccountInvitation
+    BusinessSubscriptionPlan, SubAccountPermission, EFBSubAccountInvitation,
+    SubAccountTransactionLimit, SubAccountTransactionAuthorization
 
 )
 
@@ -70,6 +87,7 @@ from django.http import JsonResponse, HttpResponseBadRequest
 from v2.business_management.efb.utils import generate_invoice_pdf, generate_business_name_acronym, get_business_name
 from v2.business_management.efb.tasks import (send_business_verification_process_email_to_EFB_user, send_creation_notification_email_to_employee,
                     send_kyc_completion_email_to_compliance, send_business_document_confirmation_email, send_subscription_email)
+from .services.payroll import get_payroll_summary
 from .verifications import validate_verified_efb_user
 
 from notification.utils import create_user_notification
@@ -86,8 +104,14 @@ from rest_framework.permissions import AllowAny
 from v2.business_management.efb.permissions import (
     IsValidatedEFBUser, BusinessSuite, EffectiveUserPermission, VerifiedUser, get_verified_permissions
 )
-from v2.user_management.efb_subaccounts import EFBSubaccountProcessor #
-from rest_framework.exceptions import ValidationError
+from v2.business_management.efb.choices import (
+    SUBACCOUNT_STATUS_ACTIVE,
+    SUBACCOUNT_STATUS_DEACTIVATED,
+    SUBACCOUNT_STATUS_PENDING,
+    SUBACCOUNT_STATUS_REMOVED
+)
+from v2.user_management.efb_subaccounts import EFBSubaccountProcessor, SUBACCOUNT_NOT_FOUND_MESSAGE
+from rest_framework.exceptions import ValidationError, PermissionDenied
 
 
 log = logging.getLogger(__name__)
@@ -1017,6 +1041,57 @@ class PaySalaryViewSets(viewsets.ViewSet):
         return Response(serializer.data, status=status.HTTP_200_OK)
 
 
+class PayrollSummaryAPIView(APIView):
+    permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
+
+    @extend_schema(
+        summary="Retrieve payroll activity summary",
+        description="Returns a summary of payroll activity for a given pay period, including number of employees paid, total amount disbursed per currency, and number of pending employees.",
+        parameters=[PayrollSummaryQuerySerializer],
+        responses={200: PayrollSummarySerializerOut}
+    )
+    @handle_exceptions
+    def get(self, request, business_id):
+
+        business = get_object_or_404(ExpedierForBusiness, id=business_id)
+
+        if business.user_account_type.user != request.user:
+            return Response(
+                {"status": "failed", "message": "You do not have permission to access this business's payroll summary."},
+                status=status.HTTP_403_FORBIDDEN
+            )
+
+        employer_user = business.user_account_type.user
+
+        query_serializer = PayrollSummaryQuerySerializer(data=request.query_params)
+        query_serializer.is_valid(raise_exception=True)
+
+        payroll_filters = query_serializer.filters
+        cache_key = query_serializer.get_cache_key(business_id)
+        cached_data = cache.get(cache_key)
+
+        if cached_data:
+            serializer = PayrollSummarySerializerOut(cached_data)
+            return Response(
+                {
+                    "status": "success",
+                    "message": "Payroll activity summary retrieved successfully.",
+                    "data": serializer.data,
+                },
+                status=status.HTTP_200_OK
+            )
+
+        data = get_payroll_summary(employer_user, business_id, **payroll_filters)
+
+        serializer = PayrollSummarySerializerOut(data)
+        cache.set(cache_key, serializer.data, timeout=86400)
+
+        return Response(
+            {"status": "success", "message": "Payroll activity summary retrieved successfully.",
+             "data": serializer.data},
+            status=status.HTTP_200_OK
+        )
+
 class SubscriptionViewSets(viewsets.ViewSet):
     permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
 
@@ -1559,12 +1634,46 @@ class SubAccountPermissionAdminView(APIView):
         """
         Return all SubAccountPermission objects linked to the current admin user
         """
-        return SubAccountPermission.objects.filter(business__user_account_type__user=self.request.user, 
-                                                   business__user_account_type__current=True)
+        requested_status = self.request.query_params.get("status", "all")
+        
+        # Validate status, fallback to all if invalid
+        valid_statuses = [
+            SUBACCOUNT_STATUS_ACTIVE, 
+            SUBACCOUNT_STATUS_DEACTIVATED, 
+            SUBACCOUNT_STATUS_PENDING,
+            "all"
+        ]
+        
+        if requested_status not in valid_statuses:
+            requested_status = "all"
+
+        queryset = SubAccountPermission.objects.filter(
+            business__user_account_type__user=self.request.user,
+            business__user_account_type__current=True
+        )
+
+        if requested_status != "all":
+            queryset = queryset.filter(status=requested_status)
+        else:
+            queryset = queryset.exclude(status=SUBACCOUNT_STATUS_REMOVED)
+
+        return queryset
 
     def get_object(self, sub_perm_id):
+        """
+        Fetch a specific sub-account permission by ID.
+        query the DB directly here instead of using get_queryset() to 
+        successfully fetch a deactivated account by ID without needing 
+        the '?status=deactivated' parameter in the URL.
+        """
         try:
-            return self.get_queryset().get(id=sub_perm_id)
+            return SubAccountPermission.objects.exclude(
+                status=SUBACCOUNT_STATUS_REMOVED
+            ).get(
+                id=sub_perm_id,
+                business__user_account_type__user=self.request.user,
+                business__user_account_type__current=True
+            )
         except SubAccountPermission.DoesNotExist:
             raise ValidationError({"detail": "Sub-account permission not found"})
         
@@ -1581,16 +1690,20 @@ class SubAccountPermissionAdminView(APIView):
             return Response(serializer.data)
         else:
             accepted_queryset = self.get_queryset()
-            pending_invitations = EFBSubAccountInvitation.objects.filter(
-                invited_by=request.user,
-                is_accepted=False,
-                status="pending",
-            )
-
             accepted_serializer = SubAccountSerializer(accepted_queryset, many=True)
-            pending_serializer = PendingSubAccountSerializer(pending_invitations, many=True)
+            combined_data = accepted_serializer.data
+
+            # Only add pending invites if checking the active status or all statuses
+            status_param = request.query_params.get("status", "all")
+            if status_param in [SUBACCOUNT_STATUS_ACTIVE, "all"]:
+                pending_invitations = EFBSubAccountInvitation.objects.filter(
+                    invited_by=request.user,
+                    is_accepted=False,
+                    status="pending",
+                )
+                pending_serializer = PendingSubAccountSerializer(pending_invitations, many=True)
+                combined_data += pending_serializer.data
 
-            combined_data = accepted_serializer.data + pending_serializer.data
             paginator = MyCustomPagination()
             paginated_subaccounts = paginator.paginate_queryset(combined_data, request)
             return paginator.get_paginated_response(paginated_subaccounts)
@@ -1622,7 +1735,53 @@ class SubAccountPermissionAdminView(APIView):
         sub_perm.refresh_from_db()
         response_serializer = SubAccountSerializer(sub_perm)
         return Response(response_serializer.data)
-    
+
+    @extend_schema(
+        summary="Remove sub-account by email",
+        description="Soft-remove a sub-account or pending invitation by email.",
+        request=SubAccountRemoveRequestSerializer,
+        responses={
+            200: SubAccountRemoveResponseSerializer,
+            403: SubAccountRemoveResponseSerializer,
+            404: SubAccountRemoveResponseSerializer,
+        },
+        parameters=[] + extra_headers,
+    )
+    def delete(self, request, *args, **kwargs):
+        actor = getattr(request, "logged_in_user", request.user)
+        if actor.profile.parent:
+            response_serializer = SubAccountRemoveResponseSerializer({
+                "detail": "You do not have permission to remove this sub-account.",
+            })
+            return Response(response_serializer.data, status=status.HTTP_403_FORBIDDEN)
+
+        request_serializer = SubAccountRemoveRequestSerializer(data=request.data)
+        request_serializer.is_valid(raise_exception=True)
+        email = request_serializer.validated_data["email"]
+
+        try:
+            EFBSubaccountProcessor.remove_subaccount(
+                requested_by=actor,
+                email=email,
+            )
+        except PermissionDenied:
+            response_serializer = SubAccountRemoveResponseSerializer({
+                "detail": "You do not have permission to remove this sub-account.",
+            })
+            return Response(response_serializer.data, status=status.HTTP_403_FORBIDDEN)
+        except ValueError as exc:
+            if str(exc) == SUBACCOUNT_NOT_FOUND_MESSAGE:
+                response_serializer = SubAccountRemoveResponseSerializer({
+                    "detail": SUBACCOUNT_NOT_FOUND_MESSAGE,
+                })
+                return Response(response_serializer.data, status=status.HTTP_404_NOT_FOUND)
+            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
+
+        response_serializer = SubAccountRemoveResponseSerializer({
+            "detail": "Sub-account removed successfully.",
+        })
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
+
 
 class SubAccountStatusUpdateView(APIView):
     permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
@@ -1690,6 +1849,168 @@ class SubAccountStatusUpdateView(APIView):
             },
             status=200,
         )
-    
 
-    
\ No newline at end of file
+
+class SetRBATransactionAuthorizationView(APIView):
+    permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
+
+    @extend_schema(
+        operation_id="set_rba_transaction_otp",
+        summary="Set RBA transaction authorization settings",
+        description=(
+            "Configure RBA transaction OTP and whether per-sub-account transaction "
+            "limits are enforced. When sub-account limits are off, sub-accounts use "
+            "platform transaction limits only."
+        ),
+        request=SetRBATransactionAuthorizationSerializer,
+        responses={200: SetRBATransactionAuthorizationResponseSerializer},
+        tags=["efb"],
+    )
+    def put(self, request):
+        account = UserAccountType.objects.filter(
+            user=request.user,
+            account_type__name=ExpedierBusinessCreation.BUSINESS_IDENTIFIER,
+        ).first()
+        if not account or not account.business:
+            return Response({"detail": "Business not found"}, status=status.HTTP_404_NOT_FOUND)
+
+        serializer = SetRBATransactionAuthorizationSerializer(
+            data=request.data,
+            context={"request": request, "business": account.business},
+        )
+        serializer.is_valid(raise_exception=True)
+        business = serializer.save()
+
+        response_serializer = SetRBATransactionAuthorizationResponseSerializer({
+            "detail": "RBA transaction authorization settings updated successfully",
+            "rba_transaction_otp": business.rba_transaction_otp,
+            "enforce_subaccount_transaction_limits": (
+                business.enforce_subaccount_transaction_limits
+            ),
+        })
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
+
+
+class SubAccountSetTransactionLimitView(APIView):
+    permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
+
+    @extend_schema(
+        summary="Set sub-account transaction limits",
+        description="Create transaction limits for a sub-account by currency.",
+        request=SubAccountTransactionLimitSerializer,
+        responses={200: SubAccountTransactionLimitSetResponseSerializer},
+        tags=["efb"],
+    )
+    def post(self, request, *args, **kwargs):
+        serializer = SubAccountTransactionLimitSerializer(
+            data=request.data,
+            context={"request": request},
+        )
+        serializer.is_valid(raise_exception=True)
+        limits = serializer.save()
+
+        response_serializer = SubAccountTransactionLimitSetResponseSerializer({
+            "message": "Transaction limits set successfully",
+            "data": limits,
+        })
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
+
+
+class SubAccountGetTransactionLimitListView(APIView):
+    permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
+
+    @extend_schema(
+        summary="Get sub-account transaction limits",
+        description="Retrieve all transaction limits for a specific sub-account.",
+        responses={200: SubAccountTransactionLimitListResponseSerializer},
+        tags=["efb"],
+    )
+    def get(self, request, id, *args, **kwargs):
+        access_serializer = SubAccountGetTransactionLimitSerializer(
+            data={},
+            context={"request": request, "sub_account_id": id},
+        )
+        access_serializer.is_valid(raise_exception=True)
+        limits = access_serializer.get_limits_queryset()
+
+        response_serializer = SubAccountTransactionLimitListResponseSerializer({
+            "message": "Transaction limits retrieved successfully",
+            "data": limits,
+        })
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
+
+
+class SubAccountLimitPrefillView(APIView):
+    permission_classes = [IsValidatedEFBUser, EffectiveUserPermission]
+
+    @extend_schema(
+        summary="Get sub-account limit prefill",
+        description="Return org caps and default prefill values (cap/2) for NGN, CAD, and USD.",
+        parameters=[
+            OpenApiParameter(
+                name="email",
+                type=str,
+                location=OpenApiParameter.QUERY,
+                required=True,
+                description="Sub-account email",
+            )
+        ],
+        responses={200: SubAccountLimitPrefillResponseSerializer},
+        tags=["efb"],
+    )
+    def get(self, request):
+        query_serializer = SubAccountLimitPrefillQuerySerializer(
+            data=request.query_params,
+            context={"request": request},
+        )
+        query_serializer.is_valid(raise_exception=True)
+        payload = query_serializer.build_prefill_payload()
+
+        response_serializer = SubAccountLimitPrefillResponseSerializer(payload)
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
+
+
+class RequestRBATransactionOTPView(APIView):
+    permission_classes = [IsValidatedEFBUser]
+
+    @extend_schema(
+        operation_id="request_rba_transaction_otp",
+        summary="Request RBA Transaction OTP",
+        description="Generate and send OTP for sub-account transaction authorization.",
+        request=RequestRBATransactionOTPSerializer,
+        responses={200: RequestRBATransactionOTPResponseSerializer},
+        tags=["efb"],
+    )
+    def post(self, request):
+        serializer = RequestRBATransactionOTPSerializer(
+            data=request.data,
+            context={"request": request},
+        )
+        serializer.is_valid(raise_exception=True)
+        payload = serializer.save()
+
+        response_serializer = RequestRBATransactionOTPResponseSerializer(payload)
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
+
+
+class ValidateRBATransactionOTPView(APIView):
+    permission_classes = [IsValidatedEFBUser]
+
+    @extend_schema(
+        operation_id="validate_rba_transaction_otp",
+        summary="Validate RBA Transaction OTP",
+        description="Validate sub-account transaction OTP and mark it as used.",
+        request=ValidateRBATransactionOTPSerializer,
+        responses={200: ValidateRBATransactionOTPResponseSerializer},
+        tags=["efb"],
+    )
+    def post(self, request):
+        serializer = ValidateRBATransactionOTPSerializer(
+            data=request.data,
+            context={"request": request},
+        )
+        serializer.is_valid(raise_exception=True)
+        payload = serializer.save()
+
+        response_serializer = ValidateRBATransactionOTPResponseSerializer(payload)
+        return Response(response_serializer.data, status=status.HTTP_200_OK)
\ No newline at end of file
diff --git a/v2/entity_management/dcp_payment.py b/v2/entity_management/dcp_payment.py
index 3860ea928..8c0ad5b83 100644
--- a/v2/entity_management/dcp_payment.py
+++ b/v2/entity_management/dcp_payment.py
@@ -492,11 +492,51 @@ class DDTDataHandler:
         DateOfBirth: Optional[str]
         Email: Optional[str]
 
-    def __post_init__(self):
-        for field in ("Name", "MiddleName", "LastName"):
-            value = getattr(self, field)
-            if value:
-                setattr(self, field, value[:30])
+        def __post_init__(self):
+            """
+            Ensure the combined length of Name, MiddleName, and LastName does not exceed 30 characters
+            to comply with DCP API restrictions. By request, we combine them all into a single string,
+            truncate it to 30 characters, and then split by spaces to intelligently populate the fields.
+            """
+            # 1. Start with safe string representations
+            name = str(self.Name or "").strip()
+            middle = str(self.MiddleName or "").strip()
+            last = str(self.LastName or "").strip()
+            
+            # 2. Combine all non-empty parts into a single full name
+            parts = [p for p in [name, middle, last] if p]
+            full_name = " ".join(parts)
+            
+            # 3. If it's already 30 characters or less, do absolutely nothing!
+            if len(full_name) <= 30:
+                self.Name = name
+                self.MiddleName = middle
+                self.LastName = last
+                return
+                
+            # 4. Truncate the combined name to exactly 30 characters
+            full_name = full_name[:30].strip()
+
+            # 5. Split the truncated full name by space to distribute into fields
+            split_parts = full_name.split()
+            
+            if len(split_parts) == 1:
+                self.Name = split_parts[0]
+                self.MiddleName = ""
+                # Fallback if API strictly requires LastName but only a mononym remains
+                self.LastName = "." 
+            elif len(split_parts) == 2:
+                self.Name = split_parts[0]
+                self.MiddleName = ""
+                self.LastName = split_parts[1]
+            elif len(split_parts) > 2:
+                self.Name = split_parts[0]
+                self.LastName = split_parts[-1]
+                self.MiddleName = " ".join(split_parts[1:-1])
+            else:
+                self.Name = ""
+                self.MiddleName = ""
+                self.LastName = ""
 
     @dataclass
     class DeleteDDTRequest:
diff --git a/v2/entity_management/tests.py b/v2/entity_management/tests.py
new file mode 100644
index 000000000..907e479c0
--- /dev/null
+++ b/v2/entity_management/tests.py
@@ -0,0 +1,62 @@
+import unittest
+from v2.entity_management.dcp_payment import DDTDataHandler
+
+class UpdateDDTRequestTestCase(unittest.TestCase):
+    def test_name_truncation(self):
+        # Create an UpdateDDTRequest with names longer than 30 characters
+        long_name = "A" * 40
+        long_middle_name = "B" * 50
+        long_last_name = "C" * 35
+
+        request = DDTDataHandler.UpdateDDTRequest(
+            DDTOwnerId=1,
+            Name=long_name,
+            MiddleName=long_middle_name,
+            LastName=long_last_name,
+            DateOfBirth="1990-01-01",
+            Email="test@example.com"
+        )
+
+        # Assert that the names are truncated to 30 characters
+        self.assertEqual(len(request.Name), 30)
+        self.assertEqual(request.Name, "A" * 30)
+
+        self.assertEqual(len(request.MiddleName), 30)
+        self.assertEqual(request.MiddleName, "B" * 30)
+
+        self.assertEqual(len(request.LastName), 30)
+        self.assertEqual(request.LastName, "C" * 30)
+
+    def test_name_no_truncation_when_short(self):
+        # Create an UpdateDDTRequest with names shorter than 30 characters
+        short_name = "John"
+        short_middle_name = "Doe"
+        short_last_name = "Smith"
+
+        request = DDTDataHandler.UpdateDDTRequest(
+            DDTOwnerId=2,
+            Name=short_name,
+            MiddleName=short_middle_name,
+            LastName=short_last_name,
+            DateOfBirth="1990-01-01",
+            Email="test@example.com"
+        )
+
+        # Assert that the names are not modified
+        self.assertEqual(request.Name, short_name)
+        self.assertEqual(request.MiddleName, short_middle_name)
+        self.assertEqual(request.LastName, short_last_name)
+
+    def test_name_with_none_values(self):
+        request = DDTDataHandler.UpdateDDTRequest(
+            DDTOwnerId=3,
+            Name=None,
+            MiddleName=None,
+            LastName=None,
+            DateOfBirth="1990-01-01",
+            Email="test@example.com"
+        )
+
+        self.assertIsNone(request.Name)
+        self.assertIsNone(request.MiddleName)
+        self.assertIsNone(request.LastName)
diff --git a/v2/integration_management/dcp_configuration.py b/v2/integration_management/dcp_configuration.py
index 22e0dbeb9..274f9f9b8 100644
--- a/v2/integration_management/dcp_configuration.py
+++ b/v2/integration_management/dcp_configuration.py
@@ -341,7 +341,7 @@ class DDTClient:
             idempotency_key: Optional[str] = None,
     ) -> DDTDataHandler.ItemUpdateResponse:
         """Update DDT owner information using the /Ddt/Update endpoint."""
-        if not ddt_owner_id:
+        if ddt_owner_id is None:
             raise ValueError("DDT owner ID is required")
 
         if not name:
@@ -379,7 +379,10 @@ class DDTClient:
         }
 
         LOG.info(
-            f"Updating DDT owner information: {extra}"
+            f"Updating DDT owner information. Original arguments: {extra}"
+        )
+        LOG.info(
+            f"Exact payload being sent to DCP API: {request_payload}"
         )
 
         url = self.config.get_endpoint_url("/Ddt/Update")
diff --git a/v2/integration_management/paga_client.py b/v2/integration_management/paga_client.py
index 5907a331a..9ca4ee59c 100644
--- a/v2/integration_management/paga_client.py
+++ b/v2/integration_management/paga_client.py
@@ -187,8 +187,15 @@ class PagaPayerDetails:
     payerName: Optional[str] = None
     payerBankName: Optional[str] = None
     payerBankAccountNumber: Optional[str] = None
+    payerAccountNumber: Optional[str] = None
     narration: Optional[str] = None
 
+    def __post_init__(self):
+        if self.payerBankAccountNumber and not self.payerAccountNumber:
+            self.payerAccountNumber = self.payerBankAccountNumber
+        elif self.payerAccountNumber and not self.payerBankAccountNumber:
+            self.payerBankAccountNumber = self.payerAccountNumber
+
 
 @dataclass
 class PagaPaymentCallback:
diff --git a/v2/user_management/efb_subaccounts.py b/v2/user_management/efb_subaccounts.py
index f8c211d57..e064b9569 100644
--- a/v2/user_management/efb_subaccounts.py
+++ b/v2/user_management/efb_subaccounts.py
@@ -1,13 +1,23 @@
 import uuid
 import logging
+from decimal import Decimal
 from django.conf import settings
 from django.utils import timezone
 from datetime import timedelta
+from django.core.exceptions import ObjectDoesNotExist
 from django.contrib.auth import get_user_model
 from django.shortcuts import get_object_or_404
 from django.db import transaction as db_transaction
+from rest_framework.exceptions import ValidationError, PermissionDenied
 from account.models import UserAccountType
-from v2.business_management.efb.models import EFBSubAccountInvitation, SubAccountPermission, ExpedierForBusiness
+from currency.models import CurrencyTransactionLimit, Currency
+from v2.business_management.efb.models import (
+    EFBSubAccountInvitation,
+    SubAccountPermission,
+    ExpedierForBusiness,
+    SubAccountTransactionLimit,
+    SubAccountDailyUsage,
+)
 
 from v2.business_management.efb.tasks import sub_account_invitation_email
 
@@ -15,7 +25,20 @@ from v2.business_management.efb.tasks import sub_account_invitation_email, sub_a
 
 from v2.user_management.services import SecondaryUserService
 from v2.notification_management.services import EmailNotification
+from v2.business_management.efb.choices import (
+    SUBACCOUNT_STATUS_ACTIVE,
+    SUBACCOUNT_STATUS_PENDING,
+    SUBACCOUNT_STATUS_DEACTIVATED,
+    SUBACCOUNT_STATUS_REMOVED,
+)
 from v2.user_management.repositories import UserRepository
+from v2.user_management.subaccount_access import (
+    clear_subaccount_permission_flags,
+    default_subaccount_permission_flags,
+    SUBACCOUNT_PERMISSION_FLAG_FIELDS,
+)
+
+SUBACCOUNT_NOT_FOUND_MESSAGE = "Sub-account not found or already removed."
 
 User = get_user_model()
 
@@ -30,31 +53,38 @@ class EFBSubaccountProcessor:
         """
         if invited_by.profile.parent:
             raise ValueError("Only primary account holders can invite sub-accounts")
-        
-        user = User.objects.filter(email=email).exists()
-        if user:
-            raise ValueError("A user with this email already exists")
-        
+
+        existing_user = User.objects.filter(email=email).first()
+        if existing_user:
+            existing_permission = SubAccountPermission.objects.filter(sub_account=existing_user).first()
+            if not existing_permission or existing_permission.status != SUBACCOUNT_STATUS_REMOVED:
+                raise ValueError("A user with this email already exists")
+
         invitation = EFBSubAccountInvitation.objects.filter(
             email=email).first()
 
         expires_at = timezone.now() + timedelta(days=30)
 
-        if invitation and invitation.is_accepted == True:
+        if invitation and invitation.status == SUBACCOUNT_STATUS_ACTIVE:
             raise ValueError("An active user with this email already exists")
-        elif invitation and invitation.is_accepted == False:
-            invitation.token=uuid.uuid4()
-            invitation.status="pending"
-            invitation.is_accepted=False
+        elif invitation and invitation.status in (
+            SUBACCOUNT_STATUS_PENDING,
+            SUBACCOUNT_STATUS_REMOVED,
+            SUBACCOUNT_STATUS_DEACTIVATED,
+        ):
+            invitation.name = name
+            invitation.token = uuid.uuid4()
+            invitation.status = SUBACCOUNT_STATUS_PENDING
+            invitation.is_accepted = False
             invitation.expires_at = expires_at
             invitation.updated_at = timezone.now()
-            invitation.save(update_fields=["token", "status", "is_accepted", "expires_at", "updated_at"])
+            invitation.save(update_fields=["name", "token", "status", "is_accepted", "expires_at", "updated_at"])
         else:
             invitation = EFBSubAccountInvitation.objects.create(
                 email=email,
                 name=name,
                 token=uuid.uuid4(),
-                status="pending",
+                status=SUBACCOUNT_STATUS_PENDING,
                 invited_by=invited_by,
                 expires_at=expires_at,
             )
@@ -100,14 +130,26 @@ class EFBSubaccountProcessor:
             )
 
             invitation.is_accepted = True
-            invitation.status = "active"
+            invitation.status = SUBACCOUNT_STATUS_ACTIVE
             invitation.accepted_at = timezone.now()
             invitation.save(update_fields=["is_accepted", "status", "accepted_at"])
 
+            sub_account_user = User.objects.get(email=invitation.email)
+            sub_account_user.is_active = True
+            sub_account_user.profile.active = True
+            sub_account_user.save(update_fields=["is_active"])
+            sub_account_user.profile.save(update_fields=["active"])
 
             try:
                 UserAccountType.objects.filter(user__email=invitation.email).update(name=primary_details["business_name"])
-                SubAccountPermission.objects.create(sub_account=User.objects.get(email=invitation.email), business=primary_details["business_object"])
+                SubAccountPermission.objects.update_or_create(
+                    sub_account=sub_account_user,
+                    business=primary_details["business_object"],
+                    defaults={
+                        "status": SUBACCOUNT_STATUS_ACTIVE,
+                        **default_subaccount_permission_flags(),
+                    },
+                )
             except Exception as e:
                 log.error(f"Error occurred while creating sub-account: {str(e)}")
                 raise ValueError("Failed to create sub-account")
@@ -141,16 +183,24 @@ class EFBSubaccountProcessor:
         Activate or deactivate a sub-account user under the primary account holder.
         Returns the user and invitation instance (or None if no invitation exists)
         """
+        valid_statuses = [SUBACCOUNT_STATUS_ACTIVE, SUBACCOUNT_STATUS_DEACTIVATED]
+        normalized_status = status.lower()
+
+        if normalized_status not in valid_statuses:
+            raise ValueError(
+                f"Invalid status '{status}'. Allowed values are: {', '.join(valid_statuses)}."
+            )
 
         if requested_by.profile.parent:
             raise ValueError("Only primary account holders can modify sub-accounts")
 
         primary_details = EFBSubaccountProcessor.retrieve_pry_account_details(requested_by)
+        business = EFBSubaccountProcessor._require_business_object(primary_details)
 
         try:
             sub_permission = SubAccountPermission.objects.select_related("sub_account").get(
                 sub_account__email=email,
-                business=primary_details["business_object"],
+                business=business,
             )
         except SubAccountPermission.DoesNotExist:
             raise ValueError("Sub-account not found under your business")
@@ -160,6 +210,9 @@ class EFBSubaccountProcessor:
         if user == requested_by:
             raise ValueError("You cannot modify your own activation status")
 
+        if sub_permission.status == SUBACCOUNT_STATUS_REMOVED:
+            raise ValueError("Sub-account was removed. Re-invite them to restore access.")
+
         user.is_active = bool(is_active)
         user.profile.active = bool(is_active)
         user.save(update_fields=["is_active"])
@@ -170,6 +223,9 @@ class EFBSubaccountProcessor:
             invitation.status = status
             invitation.save(update_fields=["status"])
 
+        sub_permission.status = status
+        sub_permission.save(update_fields=["status"])
+
         log.info(
             f"Sub-account status updated | "
             f"Primary: {requested_by.email} | "
@@ -178,9 +234,78 @@ class EFBSubaccountProcessor:
         )
 
         return user, invitation
-    
+
+    @staticmethod
+    @db_transaction.atomic
+    def remove_subaccount(*, requested_by, email: str):
+        """
+        Soft-remove a sub-account or pending invitation under the primary account holder.
+        """
+        if requested_by.profile.parent:
+            raise PermissionDenied("You do not have permission to remove this sub-account.")
+
+        primary_details = EFBSubaccountProcessor.retrieve_pry_account_details(requested_by)
+        business = EFBSubaccountProcessor._require_business_object(primary_details)
+
+        sub_permission = SubAccountPermission.objects.filter(
+            sub_account__email=email,
+            business=business,
+        ).select_related("sub_account").first()
+
+        if sub_permission:
+            if sub_permission.status == SUBACCOUNT_STATUS_REMOVED:
+                raise ValueError(SUBACCOUNT_NOT_FOUND_MESSAGE)
+
+            user = sub_permission.sub_account
+            user.is_active = False
+            user.profile.active = False
+            user.save(update_fields=["is_active"])
+            user.profile.save(update_fields=["active"])
+
+            sub_permission.status = SUBACCOUNT_STATUS_REMOVED
+            clear_subaccount_permission_flags(sub_permission)
+            sub_permission.save(update_fields=["status", *SUBACCOUNT_PERMISSION_FLAG_FIELDS])
+
+            invitation = EFBSubAccountInvitation.objects.filter(
+                email=email,
+                invited_by=requested_by,
+            ).first()
+            if invitation:
+                invitation.status = SUBACCOUNT_STATUS_REMOVED
+                invitation.is_accepted = False
+                invitation.save(update_fields=["status", "is_accepted"])
+
+            log.info(
+                f"Sub-account removed | Primary: {requested_by.email} | Sub-account: {email}"
+            )
+            return user
+
+        invitation = EFBSubAccountInvitation.objects.filter(
+            email=email,
+            invited_by=requested_by,
+        ).first()
+
+        if invitation:
+            if invitation.status == SUBACCOUNT_STATUS_REMOVED:
+                raise ValueError(SUBACCOUNT_NOT_FOUND_MESSAGE)
+            if not invitation.is_accepted:
+                invitation.status = SUBACCOUNT_STATUS_REMOVED
+                invitation.save(update_fields=["status"])
+                log.info(
+                    f"Pending sub-account invitation removed | Primary: {requested_by.email} | Email: {email}"
+                )
+                return None
+
+        raise ValueError(SUBACCOUNT_NOT_FOUND_MESSAGE)
 
     
+    @staticmethod
+    def _require_business_object(primary_details):
+        business = primary_details["business_object"]
+        if business is None:
+            raise ValueError("Your organization details not found")
+        return business
+    
     @staticmethod
     def primary_account_holder(*, primary_account_user):
         """
@@ -205,5 +330,182 @@ class EFBSubaccountProcessor:
             "business_object": business_object,
         }
 
-    
-        
\ No newline at end of file
+
+class SubAccountLimitService:
+
+    @staticmethod
+    def validate_against_business_limits(*, business, currency, single_limit, daily_limit):
+        user = business.user_account_type.user
+        account_type = user.profile.account_type
+        if not account_type:
+            raise ValidationError({"detail": "Business account type is not configured"})
+        is_verified = user.profile.is_verified()
+
+        currency_limit = CurrencyTransactionLimit.get_resolved_limit(
+            account_type=account_type,
+            currency=currency,
+            for_verified_user=is_verified,
+        )
+        if not currency_limit or not currency_limit.active:
+            raise ValueError(f"Business transaction limits not configured for {currency.code}")
+
+        if single_limit > currency_limit.max_single_external_transfer_amount:
+            raise ValidationError({
+                "detail": (
+                    "Single limit cannot exceed business max of "
+                    f"{currency_limit.max_single_external_transfer_amount}. Kindly reach out to support."
+                )
+            })
+
+        if daily_limit > currency_limit.max_daily_external_transfer_amount:
+            raise ValidationError({
+                "detail": (
+                    "Daily limit cannot exceed business max of "
+                    f"{currency_limit.max_daily_external_transfer_amount}. Kindly reach out to support."
+                )
+            })
+
+    @staticmethod
+    def update_or_create_limit(*, sub_account, business, currency, single_limit, daily_limit):
+        currency_obj = Currency.objects.filter(id=currency).first()
+        if not currency_obj:
+            raise ValidationError({"detail": "Invalid currency"})
+
+        single_limit = Decimal(single_limit)
+        daily_limit = Decimal(daily_limit)
+
+        if single_limit <= 0:
+            raise ValidationError({"detail": "Single limit must be greater than 0"})
+
+        if daily_limit < single_limit:
+            raise ValidationError({"detail": "Daily limit cannot be less than single limit"})
+
+        with db_transaction.atomic():
+            SubAccountLimitService.validate_against_business_limits(
+                business=business,
+                currency=currency_obj,
+                single_limit=single_limit,
+                daily_limit=daily_limit,
+            )
+
+            obj, _ = SubAccountTransactionLimit.objects.update_or_create(
+                sub_account=sub_account,
+                business=business,
+                currency=currency_obj,
+                defaults={
+                    "single_limit": single_limit,
+                    "daily_limit": daily_limit,
+                },
+            )
+
+        return obj
+
+    @staticmethod
+    def validate(*, request, currency, amount: Decimal):
+        """
+        Validate single + daily limits before transaction.
+        Returns usage context dict or None when caller is not a sub-account.
+        """
+        logged_in_user = getattr(request, "logged_in_user", None)
+
+        if not (
+            logged_in_user
+            and hasattr(logged_in_user, "profile")
+            and logged_in_user.profile.parent
+        ):
+            return None
+
+        parent_user = logged_in_user.profile.parent.user
+        business = ExpedierForBusiness.objects.filter(
+            user_account_type__user=parent_user
+        ).first()
+
+        if not business:
+            raise ValidationError({"detail": "Business not found. Kindly reach out to admin."})
+
+        if not business.enforce_subaccount_transaction_limits:
+            return None
+
+        sub_account = logged_in_user
+        today = timezone.now().date()
+
+        try:
+            limit = SubAccountTransactionLimit.objects.get(
+                sub_account=sub_account,
+                business=business,
+                currency=currency,
+            )
+        except SubAccountTransactionLimit.DoesNotExist:
+            raise ValidationError({"detail": "Transaction limit not configured. Kindly reach out to admin."})
+
+        if amount > limit.single_limit:
+            raise ValidationError({
+                "detail": f"Amount exceeds single limit of {limit.single_limit}. Kindly reach out to admin."
+            })
+
+        usage, _ = SubAccountDailyUsage.objects.select_for_update().get_or_create(
+            sub_account=sub_account,
+            business=business,
+            currency=currency,
+            usage_date=today,
+            defaults={"total_amount": Decimal("0")},
+        )
+
+        new_total = usage.total_amount + amount
+        if new_total > limit.daily_limit:
+            raise ValidationError({
+                "detail": (
+                    f"Amount exceeds daily limit: You have {currency.code} "
+                    f"{limit.daily_limit - usage.total_amount} left for today. Kindly reach out to admin."
+                )
+            })
+
+        return {
+            "sub_account": sub_account,
+            "business": business,
+            "currency": currency,
+            "amount": amount,
+            "daily_limit": limit.daily_limit,
+        }
+
+    @staticmethod
+    def record_usage(*, sub_account, business, currency, amount: Decimal, daily_limit: Decimal):
+        today = timezone.now().date()
+        usage, _ = SubAccountDailyUsage.objects.select_for_update().get_or_create(
+            sub_account=sub_account,
+            business=business,
+            currency=currency,
+            usage_date=today,
+            defaults={"total_amount": Decimal("0")},
+        )
+
+        new_total = usage.total_amount + amount
+        if new_total > daily_limit:
+            raise ValidationError({
+                "detail": (
+                    f"Amount exceeds daily limit: You have {currency.code} "
+                    f"{daily_limit - usage.total_amount} left for today"
+                )
+            })
+
+        usage.total_amount = new_total
+        usage.save(update_fields=["total_amount"])
+
+    @staticmethod
+    def complete_transfer(*, request, currency, amount: Decimal, transfer_callable):
+        with db_transaction.atomic():
+            usage_context = SubAccountLimitService.validate(
+                request=request,
+                currency=currency,
+                amount=amount,
+            )
+
+            success, response = transfer_callable()
+            if not success:
+                db_transaction.set_rollback(True)
+                return success, response
+
+            if usage_context:
+                SubAccountLimitService.record_usage(**usage_context)
+
+        return success, response
\ No newline at end of file
diff --git a/v2/user_management/repositories.py b/v2/user_management/repositories.py
index be64a70c0..4523131a2 100644
--- a/v2/user_management/repositories.py
+++ b/v2/user_management/repositories.py
@@ -5,6 +5,8 @@ from django.db import transaction
 from django.shortcuts import get_object_or_404
 
 from account.models import Profile
+from v2.business_management.efb.choices import SUBACCOUNT_STATUS_REMOVED
+from v2.business_management.efb.models import SubAccountPermission
 from v2.user_management.interfaces import UserRepositoryInterface
 
 
@@ -39,6 +41,17 @@ class UserRepository(UserRepositoryInterface):
             raise ValueError("A secondary user cannot create another secondary user.")
 
         if User.objects.filter(email=secondary_user_email).exists():
+            existing_user = User.objects.get(email=secondary_user_email)
+            existing_permission = SubAccountPermission.objects.filter(
+                sub_account=existing_user
+            ).first()
+            if existing_permission and existing_permission.status == SUBACCOUNT_STATUS_REMOVED:
+                return self._restore_removed_secondary_user(
+                    primary_profile=primary_profile,
+                    secondary_user=existing_user,
+                    secondary_user_password=kwargs.get("secondary_user_password"),
+                    secondary_user_name=kwargs.get("secondary_user_name"),
+                )
             raise ValueError("A user with this email already exists.")
 
         # Create secondary user
@@ -70,3 +83,32 @@ class UserRepository(UserRepositoryInterface):
                 secondary_profile.save()
 
         return secondary_user, secondary_profile
+
+    def _restore_removed_secondary_user(
+        self,
+        *,
+        primary_profile,
+        secondary_user,
+        secondary_user_password,
+        secondary_user_name,
+    ) -> Tuple[User, Profile]:
+        with transaction.atomic():
+            full_name = (secondary_user_name or "").strip()
+            parts = full_name.split()
+            first_name = parts[0] if parts else ""
+            last_name = " ".join(parts[1:]) if len(parts) > 1 else ""
+
+            secondary_user.first_name = first_name
+            secondary_user.last_name = last_name
+            secondary_user.is_active = True
+            secondary_user.set_password(secondary_user_password)
+            secondary_user.save(update_fields=["first_name", "last_name", "is_active", "password"])
+
+            secondary_profile = secondary_user.profile
+            secondary_profile.parent = primary_profile
+            secondary_profile.active = True
+            if primary_profile.account_type_id:
+                secondary_profile.account_type = primary_profile.account_type
+            secondary_profile.save(update_fields=["parent", "active", "account_type"])
+
+        return secondary_user, secondary_profile
diff --git a/v2/user_management/subaccount_access.py b/v2/user_management/subaccount_access.py
new file mode 100644
index 000000000..b6ecc0670
--- /dev/null
+++ b/v2/user_management/subaccount_access.py
@@ -0,0 +1,54 @@
+from rest_framework.exceptions import AuthenticationFailed
+
+from v2.business_management.efb.choices import (
+    SUBACCOUNT_STATUS_ACTIVE,
+    SUBACCOUNT_STATUS_DEACTIVATED,
+    SUBACCOUNT_STATUS_REMOVED,
+)
+from v2.business_management.efb.models import SubAccountPermission
+
+SUBACCOUNT_PERMISSION_FLAG_FIELDS = (
+    "can_view_transactions",
+    "can_view_account_details",
+    "can_swap_funds",
+    "can_transfer_funds",
+    "can_create_wallets",
+)
+
+
+def is_efb_subaccount(user):
+    profile = getattr(user, "profile", None)
+    return profile is not None and profile.parent_id is not None
+
+
+def get_subaccount_permission(user):
+    if not is_efb_subaccount(user):
+        return None
+    return SubAccountPermission.objects.filter(sub_account=user).first()
+
+
+def clear_subaccount_permission_flags(permission):
+    for field in SUBACCOUNT_PERMISSION_FLAG_FIELDS:
+        setattr(permission, field, False)
+
+
+def default_subaccount_permission_flags():
+    return {field: False for field in SUBACCOUNT_PERMISSION_FLAG_FIELDS}
+
+
+def get_subaccount_login_block_message(user):
+    permission = get_subaccount_permission(user)
+    if permission and permission.status == SUBACCOUNT_STATUS_REMOVED:
+        return "Account removed by your company, please contact support."
+    if permission and permission.status == SUBACCOUNT_STATUS_DEACTIVATED:
+        return "Account deactivated by your company, please contact support."
+    return "Account deactivated by your company, please contact support."
+
+
+def enforce_subaccount_access(user):
+    if not is_efb_subaccount(user):
+        return
+
+    permission = get_subaccount_permission(user)
+    if not user.is_active or permission is None or permission.status != SUBACCOUNT_STATUS_ACTIVE:
+        raise AuthenticationFailed(get_subaccount_login_block_message(user))
diff --git a/v2/user_management/tests/test_unified_transfer_endpoints.py b/v2/user_management/tests/test_unified_transfer_endpoints.py
index 5c21b8b73..0678d9e40 100644
--- a/v2/user_management/tests/test_unified_transfer_endpoints.py
+++ b/v2/user_management/tests/test_unified_transfer_endpoints.py
@@ -64,6 +64,14 @@ class UnifiedTransferEndpointTests(APITestCase):
             "status": "active"
         }
 
+        self.patcher_ddt_serializer = patch(
+            'account.serializers.serializers.DDTAssignmentService'
+        )
+        self.mock_ddt_serializer = self.patcher_ddt_serializer.start()
+        self.mock_ddt_serializer.return_value.get_user_provisioning_status.return_value = {
+            "status": "active"
+        }
+
         self.patcher_consistent = patch(
             'v2.user_management.transactions.entities.is_balance_consistent',
             return_value=True,
@@ -1480,3 +1488,52 @@ class UnifiedTransferEndpointTests(APITestCase):
 
 
 
+
+    def test_interac_external_intercepted_to_internal(self):
+        """
+        Verify that an external Interac e-Transfer to an email associated with a DDT assignment
+        is intercepted and routed as an internal transfer.
+        """
+        from account.models import UserBankAccount
+        from wallet.models import DDTAssignment, DDTAssignmentStatus
+        
+        # Setup UBA and DDT
+        uba = UserBankAccount.objects.create(
+            user=self.mobile_recipient,
+            account_number=self.mobile_recipient.email,
+            bank_name="Interac e-Transfer",
+            active=True
+        )
+        
+        DDTAssignment.objects.create(
+            user_id=self.mobile_recipient.id,
+            user_bank_account=uba,
+            status=DDTAssignmentStatus.ACTIVE,
+            ddt_number="DDT1234"
+        )
+        
+        self.client.force_authenticate(user=self.mobile_sender)
+        src = self.cad
+        dest = self.cad
+        src_wallet = self.mobile_sender.wallet_set.get(currency=src)
+        dest_wallet = self.mobile_recipient.wallet_set.get(currency=dest)
+        
+        initial_src_bal = src_wallet.balance
+        initial_dest_bal = dest_wallet.balance
+        
+        payload = self._get_external_payload(src, dest, 50.0)
+        # Ensure it targets the email
+        payload['email'] = self.mobile_recipient.email
+        payload['bank_name'] = 'Interac'
+        
+        response = self.client.post('/v2/transactions/execute/', payload)
+        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
+        
+        # Verify it was intercepted
+        self.assertEqual(response.data['data']['transaction_type'], 'INTERNAL_TRANSFER')
+        
+        src_wallet.refresh_from_db()
+        dest_wallet.refresh_from_db()
+        
+        self.assertLess(src_wallet.balance, initial_src_bal)
+        self.assertGreater(dest_wallet.balance, initial_dest_bal)
diff --git a/v2/user_management/transactions/entities.py b/v2/user_management/transactions/entities.py
index 169258b72..fbce5801f 100644
--- a/v2/user_management/transactions/entities.py
+++ b/v2/user_management/transactions/entities.py
@@ -152,6 +152,9 @@ class UnifiedTransactionEntity:
         Validates the transaction entity, creates destination wallet if needed,
         and checks if the user has sufficient funds including fees.
         """
+        if not user.profile.verify_transaction_pin(self.transaction_pin):
+            raise InvalidRequestException({'detail': 'Incorrect transaction pin'})
+
         from currency.models import CurrencyTransactionLimit
 
         # 1. Logic Errors
@@ -160,15 +163,18 @@ class UnifiedTransactionEntity:
         # 2. Check can_swap / can_transfer flags per account type
         account_type = user.profile.account_type
 
-        source_limit = CurrencyTransactionLimit.objects.filter(
+        user_verified = user.profile.is_verified()
+        source_limit = CurrencyTransactionLimit.get_resolved_limit(
             account_type=account_type,
             currency=self.source_currency,
-        ).order_by('-for_verified_user').first()
+            for_verified_user=user_verified
+        )
 
-        dest_limit = CurrencyTransactionLimit.objects.filter(
+        dest_limit = CurrencyTransactionLimit.get_resolved_limit(
             account_type=account_type,
             currency=self.destination_currency,
-        ).order_by('-for_verified_user').first()
+            for_verified_user=user_verified
+        )
 
         if self.is_swap_only() or self.source_currency != self.destination_currency:
             if source_limit and not source_limit.can_swap:
diff --git a/v2/user_management/transactions/services.py b/v2/user_management/transactions/services.py
index 70b4e9fef..a24aafae2 100644
--- a/v2/user_management/transactions/services.py
+++ b/v2/user_management/transactions/services.py
@@ -374,14 +374,18 @@ class UnifiedValidationService:
         transfer_fee = Decimal('0.0')
 
         from currency.models import CurrencyTransactionLimit
-        source_limit = CurrencyTransactionLimit.objects.filter(
+        user_verified = self.user.profile.is_verified()
+        source_limit = CurrencyTransactionLimit.get_resolved_limit(
             account_type=account_type,
             currency=source_currency,
-        ).order_by('-for_verified_user').first()
-        dest_limit = CurrencyTransactionLimit.objects.filter(
+            for_verified_user=user_verified
+        )
+
+        dest_limit = CurrencyTransactionLimit.get_resolved_limit(
             account_type=account_type,
             currency=destination_currency,
-        ).order_by('-for_verified_user').first()
+            for_verified_user=user_verified
+        )
 
 
         if is_swap_only or source_currency != destination_currency:
diff --git a/v2/user_management/transactions/utils.py b/v2/user_management/transactions/utils.py
new file mode 100644
index 000000000..57d736882
--- /dev/null
+++ b/v2/user_management/transactions/utils.py
@@ -0,0 +1,88 @@
+from typing import Optional, Dict, Any
+import logging
+
+from django.db.models import Q
+from account.models import UserBankAccount
+from wallet.models import (
+    DDTAssignment,
+    DDTAssignmentStatus,
+)
+
+LOG = logging.getLogger(__name__)
+
+
+def check_and_intercept_internal_transfer(
+    account_number: Optional[str] = None,
+    sender_user: Optional[Any] = None,
+) -> Optional[Dict[str, Any]]:
+    """
+    Checks if the given account_number corresponds to an active user account with a DDT assignment.
+    If so, returns a dictionary with the target user's details to mutate the payload to an internal transfer.
+    Returns None if interception is not applicable, or if the target user is the sender.
+    """
+    if not account_number:
+        return None
+
+    try:
+        query = Q()
+        account_num_clean = str(account_number).strip() if account_number else ""
+        
+        if account_num_clean:
+            query |= Q(
+                account_number=account_num_clean
+            )
+            query |= Q(
+                account_number__iexact=account_num_clean
+            )
+
+        if not query:
+            return None
+
+        uba = UserBankAccount.objects.filter(
+            query, active=True
+        ).first()
+
+        if not uba or not uba.user:
+            return None
+
+        target_user = uba.user
+
+        # If the target user is the same as the sender, this is likely an external withdrawal to their own assigned email
+        if sender_user and target_user.id == getattr(sender_user, 'id', None):
+            return None
+
+        # Determine if we should intercept based on the bank type or DDT
+        should_intercept = False
+
+        # Check if there is an active DDT assignment bound to this account (CAD/Email)
+        has_ddt = DDTAssignment.objects.filter(
+            user_id=target_user.id,
+            status=DDTAssignmentStatus.ACTIVE,
+            user_bank_account=uba,
+        ).exists()
+
+        if has_ddt:
+            should_intercept = True
+        else:
+            # For other currencies (NGN, USD, EUR, etc.), checking if it's a virtual account is sufficient
+            should_intercept = uba.is_virtual
+
+        if should_intercept:
+            LOG.info(
+                f"Intercepting transfer to {account_number} as internal transfer for user {target_user.id}"
+            )
+            recipient_id = getattr(target_user, 'profile', None)
+            recipient_uid = recipient_id.uid if recipient_id else target_user.email
+            
+            return {
+                'external_transfer': False,
+                'recipient_identifier': recipient_uid,
+                'target_user': target_user,
+            }
+    except Exception as e:
+        LOG.error(
+            f"Error checking internal transfer interception for {account_number}: {e}",
+            exc_info=True,
+        )
+
+    return None
diff --git a/v2/user_management/transactions/views.py b/v2/user_management/transactions/views.py
index 116e3186f..74a5d4969 100644
--- a/v2/user_management/transactions/views.py
+++ b/v2/user_management/transactions/views.py
@@ -26,6 +26,7 @@ from v2.user_management.transactions.services import (
     UnifiedValidationService,
     BeneficiaryManagementService,
 )
+from v2.user_management.transactions.utils import check_and_intercept_internal_transfer
 
 
 class UnifiedTransferView(APIView):
@@ -56,6 +57,22 @@ class UnifiedTransferView(APIView):
 
         entity = serializer.to_entity()
 
+        if entity.recipient_details and entity.recipient_details.external_transfer:
+            email = getattr(entity.recipient_details, 'email', None)
+            account_number = getattr(entity.recipient_details, 'account_number', None)
+            
+            interception = check_and_intercept_internal_transfer(
+                account_number=account_number or email,
+                sender_user=request.user
+            )
+            if interception:
+                entity.recipient_details.external_transfer = False
+                entity.recipient_details.recipient_identifier = interception['recipient_identifier']
+                
+                # Clear external banking details
+                for field in interception.get('clear_fields', ['bank_name', 'bank_code', 'account_number', 'routing_number', 'sort_code', 'iban', 'swift_bic']):
+                    setattr(entity.recipient_details, field, None)
+
         service = UnifiedTransactionService(
             user=request.user,
             entity=entity,
diff --git a/v2/virtual_account_management/ddt_service.py b/v2/virtual_account_management/ddt_service.py
index ffa00044c..6c37cbc5c 100644
--- a/v2/virtual_account_management/ddt_service.py
+++ b/v2/virtual_account_management/ddt_service.py
@@ -1345,13 +1345,55 @@ class DDTAssignmentService:
         if self.needs_new_ddt_request():
             self._enqueue_provisioning_task()
 
-        available_ddt = (
-            DDTAssignment.objects
-            .filter(
-                status=DDTAssignmentStatus.UNASSIGNED
-            )
-            .first()
-        )
+        while True:
+            available_ddt = (
+                DDTAssignment.objects
+                .filter(
+                    status=DDTAssignmentStatus.UNASSIGNED
+                )
+                .first()
+            )
+
+            if not available_ddt:
+                raise DDTAssignmentError("No UNASSIGNED DDT available")
+
+            # JIT Validation
+            is_valid = False
+            try:
+                if available_ddt.ddt_id:
+                    response = self.ddt_client.get_ddt_by_id(available_ddt.ddt_id)
+                    if response and response.IsSucceeded:
+                        if response.Item and response.Item.DDTNumber:
+                            ddt_status = str(response.Item.DDTNumber.DDTStatus).lower()
+                            if ddt_status in ("0", "active", "none", "", "a"):
+                                is_valid = True
+                            else:
+                                LOG.warning(
+                                    f"JIT Validation failed for DDT {available_ddt.ddt_number}: "
+                                    f"Status is {ddt_status}"
+                                )
+                        else:
+                            is_valid = True  # Assuming valid if missing detailed nested fields
+                    else:
+                        LOG.warning(f"JIT Validation failed for DDT {available_ddt.ddt_number}: Request not succeeded")
+                else:
+                    # If there's no ddt_id to validate, assume valid to avoid blocking
+                    is_valid = True
+            except Exception as e:
+                LOG.warning(f"JIT Validation failed for DDT {available_ddt.ddt_number} due to error: {e}")
+                # We'll treat exceptions as invalid to avoid assigning a broken DDT.
+                # If network fails, this could fail valid DDTs, but safety first. Wait, network error?
+                # Actually, if the network is down, we probably shouldn't cancel.
+                # For safety, let's just break and assign if it's an error, or raise error?
+                # To be completely safe and avoid canceling good DDTs due to network error,
+                # we will raise the exception if we can't validate it properly due to network.
+                raise DDTAssignmentError(f"Failed to validate DDT assignment via API: {e}")
+                
+            if is_valid:
+                break
+                
+            # If we get here, it's explicitly invalid based on API response
+            available_ddt.mark_cancelled(reason="JIT validation failed: API indicates DDT is inactive or invalid")
 
         final_account_name = (
             self._determine_account_name(
@@ -1403,6 +1445,16 @@ class DDTAssignmentService:
             f"assign-{ddt_assignment.id}"
         )
         try:
+            if not ddt_assignment.ddt_owner_id and ddt_assignment.ddt_id:
+                LOG.info(f"DDT owner ID missing for assignment {ddt_assignment.id}, fetching from API...")
+                ddt_detail = self.ddt_client.get_ddt_by_id(ddt_assignment.ddt_id)
+                if ddt_detail.IsSucceeded and ddt_detail.Item and ddt_detail.Item.DDTNumber:
+                    fetched_owner_id = ddt_detail.Item.DDTNumber.DDTOwnerId
+                    if fetched_owner_id is not None:
+                        ddt_assignment.ddt_owner_id = fetched_owner_id
+                        ddt_assignment.save(update_fields=['ddt_owner_id'])
+                        LOG.info(f"Updated missing DDT owner ID to {fetched_owner_id}")
+
             extra = {
                 "ddt_owner_id": ddt_assignment.ddt_owner_id,
                 "user_id": ddt_assignment.user_id,
diff --git a/v2/virtual_account_management/ddt_tasks.py b/v2/virtual_account_management/ddt_tasks.py
index d9abe19be..9f29c2055 100644
--- a/v2/virtual_account_management/ddt_tasks.py
+++ b/v2/virtual_account_management/ddt_tasks.py
@@ -292,6 +292,87 @@ class DDTTask:
 
             raise Exception(f"DDT provisioning failed after {self.max_retries} retries: {str(e)}")
 
+    @staticmethod
+    @shared_task(
+        bind=True
+    )
+    def validate_ddt_inventory(self, batch_size: int = 50) -> dict:
+        """
+        Celery task to validate UNASSIGNED DDT accounts periodically.
+        Marks inactive ones as CANCELLED.
+        """
+        task_id = self.request.id
+        start_time = time.time()
+
+        LOG.info(
+            "Starting DDT inventory validation",
+            extra={'task_id': task_id, 'batch_size': batch_size}
+        )
+
+        try:
+            # Fetch a batch of UNASSIGNED DDTs
+            unassigned_ddts = list(DDTAssignment.objects.filter(
+                status=DDTAssignmentStatus.UNASSIGNED
+            ).order_by('created_at')[:batch_size])
+
+            if not unassigned_ddts:
+                return {
+                    'success': True,
+                    'processed': 0,
+                    'cancelled': 0,
+                    'message': 'No UNASSIGNED DDTs to validate',
+                    'task_id': task_id
+                }
+
+            ddt_client = DDTClient()
+            cancelled_count = 0
+
+            for ddt in unassigned_ddts:
+                try:
+                    is_valid = False
+                    if ddt.ddt_id:
+                        response = ddt_client.get_ddt_by_id(ddt.ddt_id)
+                        if response and response.IsSucceeded:
+                            if response.Item and response.Item.DDTNumber:
+                                ddt_status = str(response.Item.DDTNumber.DDTStatus).lower()
+                                if ddt_status in ("0", "active", "none", "", "a"):
+                                    is_valid = True
+                            else:
+                                is_valid = True  # Missing nested fields but succeeded
+                    else:
+                        is_valid = True  # Assuming valid if no ddt_id to check
+
+                    if not is_valid:
+                        ddt.mark_cancelled(reason="Periodic validation failed: API indicates DDT is inactive")
+                        cancelled_count += 1
+                        LOG.info(f"DDT {ddt.ddt_number} marked CANCELLED by periodic validation.")
+                except Exception as e:
+                    LOG.warning(f"Failed to validate DDT {ddt.ddt_number} during periodic check: {e}")
+
+            processing_time_ms = int((time.time() - start_time) * 1000)
+
+            result = {
+                'success': True,
+                'processed': len(unassigned_ddts),
+                'cancelled': cancelled_count,
+                'task_id': task_id,
+                'processing_time_ms': processing_time_ms,
+            }
+
+            LOG.info(
+                "DDT inventory validation completed",
+                extra=result
+            )
+            return result
+
+        except Exception as e:
+            LOG.error(
+                "Error during DDT inventory validation",
+                extra={'task_id': task_id, 'error': str(e)},
+                exc_info=True
+            )
+            raise
+
     @staticmethod
     @shared_task(
         bind=True
@@ -362,7 +443,7 @@ class DDTTask:
                         'first_account_name': config.first_account_name,
                         'second_account_name': config.second_account_name,
                     },
-                    queue='ddt_provisioning'
+                    queue='celery'
                 )
 
                 result.update({
diff --git a/wallet/admin.py b/wallet/admin.py
index 845922820..f9b19a06c 100755
--- a/wallet/admin.py
+++ b/wallet/admin.py
@@ -253,3 +253,28 @@ class DDTAssignmentAdmin(admin.ModelAdmin):
     def wallet_id_display(self, obj):
         return obj.wallet_id
 
+
+@admin.register(DDTConfiguration)
+class DDTConfigurationAdmin(admin.ModelAdmin):
+    list_display = (
+        "id",
+        "auto_provisioning_enabled",
+        "minimum_unassigned_threshold",
+        "auto_request_count",
+        "price_for_ddt_extra",
+        "updated_on",
+    )
+    list_editable = (
+        "auto_provisioning_enabled",
+        "minimum_unassigned_threshold",
+        "auto_request_count",
+        "price_for_ddt_extra",
+    )
+    readonly_fields = ("created_on", "updated_on")
+
+    def has_add_permission(self, request):
+        if DDTConfiguration.objects.exists():
+            return False
+        return super().has_add_permission(request)
+
+
diff --git a/wallet/management/commands/assign_ddt.py b/wallet/management/commands/assign_ddt.py
new file mode 100644
index 000000000..fe7e4dc46
--- /dev/null
+++ b/wallet/management/commands/assign_ddt.py
@@ -0,0 +1,56 @@
+import logging
+from django.core.management.base import BaseCommand, CommandError
+from django.contrib.auth import get_user_model
+from wallet.models import Wallet
+from v2.virtual_account_management.ddt_service import DDTAssignmentService
+
+logger = logging.getLogger(__name__)
+User = get_user_model()
+
+class Command(BaseCommand):
+    help = 'Assign a DDT to a user manually outside of the normal flow.'
+
+    def add_arguments(self, parser):
+        parser.add_argument('--email', type=str, help='Email address of the user.')
+        parser.add_argument('--user-id', type=int, help='ID of the user.')
+        parser.add_argument('--account-name', type=str, help='Optional account name for the DDT.', default=None)
+
+    def handle(self, *args, **options):
+        email = options.get('email')
+        user_id = options.get('user_id')
+        account_name = options.get('account_name')
+
+        if not email and not user_id:
+            raise CommandError("Either --email or --user-id must be provided.")
+
+        try:
+            if email:
+                user = User.objects.get(email__iexact=email)
+            else:
+                user = User.objects.get(id=user_id)
+        except User.DoesNotExist:
+            raise CommandError(f"User with the provided email or ID not found.")
+
+        # Find CAD wallet
+        wallet = Wallet.objects.filter(user=user, currency__code='CAD').first()
+        if not wallet:
+            raise CommandError(f"User {user.id} does not have a CAD wallet.")
+
+        self.stdout.write(f"Found User: {user.email} (ID: {user.id})")
+        self.stdout.write(f"Found CAD Wallet: {wallet.id}")
+        self.stdout.write("Starting DDT Assignment...")
+
+        service = DDTAssignmentService()
+        try:
+            assignment = service.assign_ddt_to_wallet(
+                wallet_id=wallet.id,
+                account_name=account_name
+            )
+            self.stdout.write(self.style.SUCCESS(
+                f"Successfully assigned DDT {assignment.ddt_number} to wallet {wallet.id}.\n"
+                f"Assignment ID: {assignment.id}\n"
+                f"Status: {assignment.status}"
+            ))
+        except Exception as e:
+            self.stderr.write(self.style.ERROR(f"Exception details: {str(e)}"))
+            raise CommandError(f"Failed to assign DDT: {str(e)}")
diff --git a/wallet/models.py b/wallet/models.py
index 6fd38d59c..5d3806706 100755
--- a/wallet/models.py
+++ b/wallet/models.py
@@ -665,6 +665,20 @@ class DDTAssignment(models.Model):
         self.status = DDTAssignmentStatus.ACTIVE
         self.save(update_fields=['status', 'updated_at'])
 
+    def mark_cancelled(self, reason: str = "") -> None:
+        """Mark DDT as cancelled (e.g. invalid on external service)."""
+        self.status = DDTAssignmentStatus.CANCELLED
+        self.save(update_fields=['status', 'updated_at'])
+        
+        # Log the cancellation
+        DDTTransactionLog.log_transaction(
+            transaction_type=DDTTransactionType.MONITORING_FAILURE,
+            ddt_assignment=self,
+            user_id=self.user_id,
+            wallet_id=self.wallet_id,
+            error_message=reason or "DDT marked as cancelled."
+        )
+
 
 class DDTTransactionLog(models.Model):
     """Audit log for all DDT-related transactions."""
diff --git a/wallet/serializers.py b/wallet/serializers.py
index 111a5c953..b7d1c6a63 100755
--- a/wallet/serializers.py
+++ b/wallet/serializers.py
@@ -80,10 +80,12 @@ class WalletSerializerIn(
         
         if user and currency:
             account_type = user.profile.account_type
-            limit = CurrencyTransactionLimit.objects.filter(
+            user_verified = user.profile.is_verified()
+            limit = CurrencyTransactionLimit.get_resolved_limit(
                 account_type=account_type,
                 currency=currency,
-            ).order_by('-for_verified_user').first()
+                for_verified_user=user_verified
+            )
             if limit and not limit.can_request_wallet:
                 raise InvalidRequestException({
                     "detail": f"You cannot request a wallet in {currency.code} at this time."
diff --git a/wallet/tests.py b/wallet/tests.py
index 63cee8c3c..ea5ac1c66 100755
--- a/wallet/tests.py
+++ b/wallet/tests.py
@@ -1678,6 +1678,59 @@ class DDTIntegrationTestCase(DDTAssignmentServiceTestCase):
         self.assertIsNotNone(assignment)
         self.assertEqual(assignment.wallet_id, wallet.id)
 
+
+class DDTTaskValidationTestCase(DDTAssignmentServiceTestCase):
+    """Test cases for periodic DDT task validation."""
+
+    def test_validate_ddt_inventory_task(self):
+        """Test the validate_ddt_inventory Celery task."""
+        from v2.virtual_account_management.ddt_tasks import DDTTask
+        
+        # Clear existing unassigned DDTs
+        DDTAssignment.objects.filter(status=DDTAssignmentStatus.UNASSIGNED).delete()
+        
+        # Create 3 unassigned DDT assignments
+        unassigned_ddts = self._create_available_ddt_assignments(3)
+        self.assertEqual(DDTAssignment.objects.filter(status=DDTAssignmentStatus.UNASSIGNED).count(), 3)
+        
+        # Mock the external get_ddt_by_id response
+        def mock_get_ddt_by_id(ddt_id):
+            mock_response = Mock()
+            mock_response.IsSucceeded = True
+            
+            # 1st is Valid ('0')
+            if ddt_id == unassigned_ddts[0].ddt_id:
+                mock_response.Item.DDTNumber.DDTStatus = '0'
+            # 2nd is Invalid ('1')
+            elif ddt_id == unassigned_ddts[1].ddt_id:
+                mock_response.Item.DDTNumber.DDTStatus = '1'
+            # 3rd is Missing nested fields, should default to Valid
+            elif ddt_id == unassigned_ddts[2].ddt_id:
+                del mock_response.Item.DDTNumber
+                
+            return mock_response
+            
+        self.mock_ddt_client.get_ddt_by_id.side_effect = mock_get_ddt_by_id
+        
+        with patch('v2.virtual_account_management.ddt_tasks.DDTClient', return_value=self.mock_ddt_client):
+            task = DDTTask()
+            task.request = Mock(id='task-123')
+            result = task.validate_ddt_inventory(batch_size=10)
+            
+        self.assertTrue(result['success'])
+        self.assertEqual(result['processed'], 3)
+        self.assertEqual(result['cancelled'], 1)
+        
+        # Verify the 2nd DDT was cancelled
+        unassigned_ddts[1].refresh_from_db()
+        self.assertEqual(unassigned_ddts[1].status, DDTAssignmentStatus.CANCELLED)
+        
+        # Verify others are still unassigned
+        unassigned_ddts[0].refresh_from_db()
+        self.assertEqual(unassigned_ddts[0].status, DDTAssignmentStatus.UNASSIGNED)
+        unassigned_ddts[2].refresh_from_db()
+        self.assertEqual(unassigned_ddts[2].status, DDTAssignmentStatus.UNASSIGNED)
+
     @mute_signals(post_save, user_post_save, User)
     @mute_signals(post_save, wallet_post_save, Wallet)
     def test_concurrent_ddt_assignment_simulation(self):
diff --git a/wallet/views.py b/wallet/views.py
index b4eff0a39..7d9460242 100755
--- a/wallet/views.py
+++ b/wallet/views.py
@@ -1045,17 +1045,17 @@ class DDTUserUpdateView(generics.GenericAPIView):
         wallet_id = validated_data["wallet_id"]
         user = request.user
 
+        extra = {
+            "user_id": user.id,
+            "wallet_id": wallet_id,
+            "email": validated_data["email"],
+            "has_name": "name"
+                        in validated_data,
+            "has_last_name": "last_name"
+                             in validated_data,
+        }
         LOG.info(
-            "Processing DDT user information update",
-            extra={
-                "user_id": user.id,
-                "wallet_id": wallet_id,
-                "email": validated_data["email"],
-                "has_name": "name"
-                            in validated_data,
-                "has_last_name": "last_name"
-                                 in validated_data,
-            },
+            f"Processing DDT user information update: {extra}"
         )
 
         try:
```

## Code Changes
### .env.sample
**Changes:** 1 additions, file deletions
- **Lines:** -98,0 +99,3
```diff
diff --git a/.env.sample b/.env.sample
index dfcfdda86..1c84e6e6b 100755
--- a/.env.sample
+++ b/.env.sample
@@ -96,6 +96,9 @@ YOUVERIFY_API_KEY=string
 
 SERVER_ENV=admin
 
+# EFB sub-account transfer approval OTP expiry (minutes)
+RBA_TRANSACTION_OTP_EXPIRY_MINUTES=5
+
 #GUNICORN
 GUNICORN_PORT=8030
 GUNICORN_WORKERS=3
```

### account/models.py
**Changes:** 1 additions, file deletions
- **Lines:** -472,0 +473,24
```diff
diff --git a/account/models.py b/account/models.py
index 4cf598438..6f73fbea8 100755
--- a/account/models.py
+++ b/account/models.py
@@ -470,6 +470,30 @@ class Profile(models.Model):
             return True
         return False
 
+    def _get_efb_business_for_profile(self):
+        # Deferred import: efb.models imports account.models (circular if top-level).
+        from v2.business_management.efb.models import ExpedierForBusiness
+
+        user = self.user
+        if self.parent and self.parent.user:
+            user = self.parent.user
```

### account/serializers/serializers.py
**Changes:** 1 additions, file deletions
- **Lines:** -817,0 +818,4
```diff
diff --git a/account/serializers/serializers.py b/account/serializers/serializers.py
index da6ba0e41..e98ed73ec 100755
--- a/account/serializers/serializers.py
+++ b/account/serializers/serializers.py
@@ -815,6 +815,10 @@ class ProfileSerializerOut(serializers.ModelSerializer):
     business_name = serializers.CharField(source='get_EFB_business_name.name', read_only=True)
     is_efb_subaccount = serializers.BooleanField(source='efb_subaccount')    
     efb_subaccount_permissions = serializers.SerializerMethodField() 
+    rba_transaction_otp = serializers.BooleanField(source='rba_transaction_otpp')
+    enforce_subaccount_transaction_limits = serializers.BooleanField(
+        source='enforce_subaccount_transaction_limits_enabled'
+    )
     transaction_pin = serializers.BooleanField(source='get_transaction_pin')
     transaction_pin_hashed = serializers.BooleanField(source='is_transaction_pin_hashed')
     bank_accounts = serializers.SerializerMethodField()
```

### account/views.py
**Changes:** 1 additions, file deletions
- **Lines:** -36,0 +37
- **Lines:** -585 +586
- **Lines:** -1386 +1387,8
```diff
diff --git a/account/views.py b/account/views.py
index cc4b8d950..a4170e413 100755
--- a/account/views.py
+++ b/account/views.py
@@ -34,6 +34,7 @@ from account.filters import UserBankAccountFilter, UserRecipientFilter, AccountT
 from account.serializers.admin import UserSummarySerializerOut, UserSerializerIn
 from account.utils import get_client_ip, create_user_meta, process_recipients_update, add_phone_validation_to_users, \
     get_user_with_country_and_phone, handle_exceptions
+from v2.user_management.subaccount_access import get_subaccount_login_block_message
 from account.models import UserVerification, UserBankAccount, UserAccountType, AccountType, Device, UserMeta, \
     UserCountryVerification, Recipient, UserOnboardingSelection, OnboardingOption, OnboardingWalletSelection
 from account.paginations import CustomPagination
@@ -582,7 +583,7 @@ class LoginView(APIView):
                 data['code'] = 'set_password'
                 return Response(data)
```

### currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,45
```diff
diff --git a/currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py b/currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py
new file mode 100644
index 000000000..9087336f4
--- /dev/null
+++ b/currency/migrations/0034_remove_currencytransactionlimit_currency_trans_limit_and_more.py
@@ -0,0 +1,45 @@
+# Generated by Django 5.2 on 2026-06-08 18:20
+
+import django.db.models.deletion
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
```

### currency/models.py
**Changes:** 1 additions, file deletions
- **Lines:** -45,2 +45,2
- **Lines:** -92,0 +93,35
- **Lines:** -94,2 +129,10
- **Lines:** -98,7 +141
```diff
diff --git a/currency/models.py b/currency/models.py
index 32db54c90..d499a0ff6 100755
--- a/currency/models.py
+++ b/currency/models.py
@@ -42,8 +42,8 @@ class Currency(models.Model):
 
 
 class CurrencyTransactionLimit(models.Model):
-    account_type = models.ForeignKey("account.AccountType", on_delete=models.SET_NULL, null=True)
-    currency = models.ForeignKey(Currency, on_delete=models.SET_NULL, null=True)
+    account_type = models.ForeignKey("account.AccountType", on_delete=models.SET_NULL, null=True, blank=True)
+    currency = models.ForeignKey(Currency, on_delete=models.SET_NULL, null=True, blank=True)
     for_verified_user = models.BooleanField(default=False)
     
     # Feature toggles
```

### currency/serializers.py
**Changes:** 1 additions, file deletions
- **Lines:** -40 +40
- **Lines:** -44 +44
- **Lines:** -97,0 +98,9
```diff
diff --git a/currency/serializers.py b/currency/serializers.py
index 0c8fbb9d7..47809510a 100755
--- a/currency/serializers.py
+++ b/currency/serializers.py
@@ -37,11 +37,11 @@ class CurrencySerializerOut(serializers.ModelSerializer):
                 account_type = request.user.profile.account_type
                 verified = request.user.profile.is_verified()
                 
-                limit = CurrencyTransactionLimit.objects.filter(
+                limit = CurrencyTransactionLimit.get_resolved_limit(
                     account_type=account_type,
                     currency=obj,
                     for_verified_user=verified
-                ).first()
+                )
```

### expedier/authentication.py
**Changes:** 1 additions, file deletions
- **Lines:** -3,0 +4,2
- **Lines:** -26 +28,3
```diff
diff --git a/expedier/authentication.py b/expedier/authentication.py
index 3b81aaa04..69d65904d 100644
--- a/expedier/authentication.py
+++ b/expedier/authentication.py
@@ -1,6 +1,8 @@
 from rest_framework_simplejwt.authentication import JWTAuthentication
 from rest_framework.exceptions import AuthenticationFailed
 
+from v2.user_management.subaccount_access import enforce_subaccount_access, is_efb_subaccount
+
 
 
 class CustomJWTAuthentication(JWTAuthentication):
@@ -23,7 +25,9 @@ class CustomJWTAuthentication(JWTAuthentication):
     def get_user(self, validated_token):
```

### expedier/celery.py
**Changes:** 1 additions, file deletions
- **Lines:** -59,0 +60,13
- **Lines:** -61,0 +75
```diff
diff --git a/expedier/celery.py b/expedier/celery.py
index 799ca5683..09f6e9f83 100644
--- a/expedier/celery.py
+++ b/expedier/celery.py
@@ -57,8 +57,22 @@ beat_schedule = {
         'schedule': crontab(hour=2, minute=30),
         'options': {'queue': 'celery'}
     },
+
+    'validate-ddt-inventory': {
+        'task': 'v2.virtual_account_management.ddt_tasks.validate_ddt_inventory',
+        'schedule': crontab(minute=0, hour='*/1'),
+        'kwargs': {'batch_size': 50},
+        'options': {'queue': 'celery'}
+    },
```

### expedier/settings/base.py
**Changes:** 1 additions, file deletions
- **Lines:** -316,0 +317
```diff
diff --git a/expedier/settings/base.py b/expedier/settings/base.py
index a13a1b75b..18c678d4e 100755
--- a/expedier/settings/base.py
+++ b/expedier/settings/base.py
@@ -314,6 +314,7 @@ SUBSCRIPTION_ANNUAL = 12
 SUBSCRIBED_USER_INACTIVITY_DAYS_REMINDER = 3
 UNSUBSCRIBED_USER_INACTIVITY_DAYS_REMINDER = 3
 EFB_MONTHLY_INCOME = env.str("EFB_MONTHLY_INCOME", "5000000+")
+RBA_TRANSACTION_OTP_EXPIRY_MINUTES = env.int("RBA_TRANSACTION_OTP_EXPIRY_MINUTES", default=5)
 INVOICE_REMINDER_DAY_TO_DUE_DATE = 1
 
 # to decide whether we are in PRE-PROD
```

### notification/emails.py
**Changes:** 1 additions, file deletions
- **Lines:** -627,0 +628,53
```diff
diff --git a/notification/emails.py b/notification/emails.py
index 2bd71cd29..d9c2c6e79 100755
--- a/notification/emails.py
+++ b/notification/emails.py
@@ -625,6 +625,59 @@ def send_bank_email_otp_to_user(user_id=None, code="", **kwargs):
     return send
 
 
+@shared_task
+def send_rba_transaction_approval_otp_email(
+    parent_user_id,
+    otp_code,
+    business_name,
+    sub_account_name,
+    amount,
```

### transaction/serializers/user.py
**Changes:** 1 additions, file deletions
- **Lines:** -360,0 +361,19
- **Lines:** -375,4 +394,5
```diff
diff --git a/transaction/serializers/user.py b/transaction/serializers/user.py
index 98a9c3d28..26e04a5a1 100755
--- a/transaction/serializers/user.py
+++ b/transaction/serializers/user.py
@@ -358,6 +358,25 @@ class AssetTransferSerializerIn(serializers.ModelSerializer):
 
     def validate(self, validated_data):
         external_transfer = validated_data.get('external_transfer')
+        email = validated_data.get('email')
+        account_number = validated_data.get('account_number')
+        
+        if external_transfer and (email or account_number):
+            from v2.user_management.transactions.utils import check_and_intercept_internal_transfer
+            interception = check_and_intercept_internal_transfer(
+                account_number=account_number or email, 
```

### transaction/tests/test_interac_interception.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,122
```diff
diff --git a/transaction/tests/test_interac_interception.py b/transaction/tests/test_interac_interception.py
new file mode 100644
index 000000000..7fbcf2ef4
--- /dev/null
+++ b/transaction/tests/test_interac_interception.py
@@ -0,0 +1,122 @@
+from decimal import Decimal
+from unittest.mock import patch
+from django.test import TestCase
+
+from factories.base import (
+    UserFactory,
+    WalletFactory,
+    CurrencyFactory,
+)
```

### transaction/utils/misc.py
**Changes:** 1 additions, file deletions
- **Lines:** -71 +70,0
- **Lines:** -95,0 +95,3
- **Lines:** -97,2 +99
- **Lines:** -167 +168
- **Lines:** -758,2 +759,5
- **Lines:** -772,0 +777
- **Lines:** -774,0 +780,6
```diff
diff --git a/transaction/utils/misc.py b/transaction/utils/misc.py
index c516ab2b4..67adab64f 100755
--- a/transaction/utils/misc.py
+++ b/transaction/utils/misc.py
@@ -68,7 +68,6 @@ INTERNAL_TRANSACTION_TYPES = {
     'swap currency',
     'asset conversion',
     'conversion',
-    'internal transfer',
 }
 
 EXTERNAL_VERIFICATION_ERROR = 'Please verify your account to send funds externally.'
@@ -93,9 +92,11 @@ def should_enforce_verification(
     if lowered_type in INTERNAL_TRANSACTION_TYPES:
         return False
```

### transaction/views/user.py
**Changes:** 1 additions, file deletions
- **Lines:** -38,0 +39
- **Lines:** -40,0 +42
- **Lines:** -168 +170,13
```diff
diff --git a/transaction/views/user.py b/transaction/views/user.py
index 40d9ee969..d2ff987c8 100755
--- a/transaction/views/user.py
+++ b/transaction/views/user.py
@@ -36,8 +36,10 @@ from transaction.utils.utils import handle_exceptions
 from rest_framework import viewsets
 from rest_framework.permissions import IsAuthenticated
 from rest_framework.request import Request
+from rest_framework.exceptions import ValidationError
 from v2.business_management.services import ExpedierBusinessCreation
 from v2.business_management.efb.permissions import EffectiveUserPermission
+from v2.user_management.efb_subaccounts import SubAccountLimitService
 
 import time
 ## Step Timer analysis
```

### v2/business_management/efb/admin.py
**Changes:** 1 additions, file deletions
- **Lines:** -6 +6,2
- **Lines:** -240 +241,79
```diff
diff --git a/v2/business_management/efb/admin.py b/v2/business_management/efb/admin.py
index 3d2f4f1f9..74059eb6a 100644
--- a/v2/business_management/efb/admin.py
+++ b/v2/business_management/efb/admin.py
@@ -3,7 +3,8 @@ from account.models import UserAccountType
 from v2.business_management.efb.models import (ExpedierForBusiness, BusinessOwner, 
 Invoice, InvoiceItem, Employee, PaidSalary, SubscriptionPlan, BusinessSubscriptionPlan, 
 BusinessJurisdiction, ZohoSignWebhookEvent, BusinessJurisdiction, SubscriptionPlanFeature, BusinessSubscriptionHistory, 
-EFBSubAccountInvitation, SubAccountPermission)
+EFBSubAccountInvitation, SubAccountPermission, SubAccountTransactionLimit,
+SubAccountDailyUsage, SubAccountTransactionAuthorization)
 from .utils import SubscriptionDurationChange as SDC
 from .forms import SubscriptionDurationForm
 
@@ -237,4 +238,82 @@ class UserInvitationAdmin(admin.ModelAdmin):
```

### v2/business_management/efb/choices.py
**Changes:** 1 additions, file deletions
- **Lines:** -50,0 +51,5
- **Lines:** -52,3 +57,4
```diff
diff --git a/v2/business_management/efb/choices.py b/v2/business_management/efb/choices.py
index b9a0ad0e7..5ffa2ef12 100644
--- a/v2/business_management/efb/choices.py
+++ b/v2/business_management/efb/choices.py
@@ -48,8 +48,14 @@ SUBSCRIPTION_EVENT_CHOICES = (
     ("expired", "Expired"),
 )
 
+SUBACCOUNT_STATUS_ACTIVE = "active"
+SUBACCOUNT_STATUS_PENDING = "pending"
+SUBACCOUNT_STATUS_DEACTIVATED = "deactivated"
+SUBACCOUNT_STATUS_REMOVED = "removed"
+
 INVITATION_STATUS_CHOICES = (
-    ("active", "Active"),
```

### v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,70
```diff
diff --git a/v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py b/v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py
new file mode 100644
index 000000000..34f9ba2f2
--- /dev/null
+++ b/v2/business_management/efb/migrations/0013_expedierforbusiness_rba_transaction_otp_and_more.py
@@ -0,0 +1,70 @@
+# Generated by Django 5.1.5 on 2026-06-02 17:27
+
+import django.db.models.deletion
+import django.utils.timezone
+from django.conf import settings
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
```

### v2/business_management/efb/migrations/0014_subaccountpermission_status.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,39
```diff
diff --git a/v2/business_management/efb/migrations/0014_subaccountpermission_status.py b/v2/business_management/efb/migrations/0014_subaccountpermission_status.py
new file mode 100644
index 000000000..c4a7a6222
--- /dev/null
+++ b/v2/business_management/efb/migrations/0014_subaccountpermission_status.py
@@ -0,0 +1,39 @@
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        ("efb", "0013_expedierforbusiness_rba_transaction_otp_and_more"),
+    ]
+
```

### v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,24
```diff
diff --git a/v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py b/v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py
new file mode 100644
index 000000000..7e6ecb877
--- /dev/null
+++ b/v2/business_management/efb/migrations/0015_subaccounttransactionauthorization_currency.py
@@ -0,0 +1,24 @@
+# Generated by Django 5.1.5
+
+import django.db.models.deletion
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
```

### v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,18
```diff
diff --git a/v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py b/v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py
new file mode 100644
index 000000000..daaed4e3d
--- /dev/null
+++ b/v2/business_management/efb/migrations/0016_expedierforbusiness_enforce_subaccount_transaction_limits.py
@@ -0,0 +1,18 @@
+# Generated by Django 5.1.5 on 2026-06-03 12:34
+
+from django.db import migrations, models
+
+
+class Migration(migrations.Migration):
+
+    dependencies = [
+        ('efb', '0015_subaccounttransactionauthorization_currency'),
```

### v2/business_management/efb/models.py
**Changes:** 1 additions, file deletions
- **Lines:** -2,0 +3
- **Lines:** -149,0 +151,2
- **Lines:** -541,0 +545
- **Lines:** -557,0 +562,77
```diff
diff --git a/v2/business_management/efb/models.py b/v2/business_management/efb/models.py
index 622d321a9..1de5b6d52 100644
--- a/v2/business_management/efb/models.py
+++ b/v2/business_management/efb/models.py
@@ -1,5 +1,6 @@
 import uuid
 from django.db import models
+from django.db import transaction
 from django.utils.timezone import now
 from django.conf import settings
 from datetime import timedelta
@@ -147,6 +148,8 @@ class ExpedierForBusiness(models.Model):
     agent_kyc_steps = models.TextField(blank=True, null=True, verbose_name="What KYC/due diligence steps are conducted by your agents?")
     processes_governed = models.BooleanField(default=False, verbose_name="Are those KYC processes governed by your firm?")
     monitoring_method = models.TextField(blank=True, null=True, verbose_name="How do you monitor your agents to ensure onboarding compliance?")
```

### v2/business_management/efb/permissions.py
**Changes:** 1 additions, file deletions
- **Lines:** -5,0 +6,2
- **Lines:** -42,0 +45,8
```diff
diff --git a/v2/business_management/efb/permissions.py b/v2/business_management/efb/permissions.py
index 1930331ad..2911f205d 100644
--- a/v2/business_management/efb/permissions.py
+++ b/v2/business_management/efb/permissions.py
@@ -3,6 +3,8 @@ from rest_framework.permissions import BasePermission
 from rest_framework.exceptions import PermissionDenied
 from rest_framework.exceptions import ValidationError
 from v2.business_management.efb.models import SubAccountPermission
+from v2.business_management.efb.choices import SUBACCOUNT_STATUS_ACTIVE
+from v2.user_management.subaccount_access import get_subaccount_permission
 from v2.business_management.efb.verifications import (
 validate_verified_efb_user, validate_active_subscription, 
 efb_business_suite_validation, get_verification_status, efb_user_account_type)
@@ -40,6 +42,14 @@ class EffectiveUserPermission(BasePermission):
             return True
```

### v2/business_management/efb/serializers.py
**Changes:** 1 additions, file deletions
- **Lines:** -2,0 +3,5
- **Lines:** -10 +14,0
- **Lines:** -21 +25,2
- **Lines:** -37,0 +43,2
- **Lines:** -45,0 +53
- **Lines:** -1366,0 +1375,9
- **Lines:** -1421,0 +1439,3
- **Lines:** -1472,0 +1493,467
- **Lines:** -1474,0 +1962,5
```diff
diff --git a/v2/business_management/efb/serializers.py b/v2/business_management/efb/serializers.py
index c5b46703c..d70646d27 100644
--- a/v2/business_management/efb/serializers.py
+++ b/v2/business_management/efb/serializers.py
@@ -1,5 +1,10 @@
 import logging
 import random
+import uuid
+from datetime import timedelta
+from decimal import Decimal, ROUND_HALF_UP
+from django.conf import settings
+from django.contrib.auth import get_user_model
 
 from django.core.signing import TimestampSigner
 from django.db import models, transaction
```

### v2/business_management/efb/services/__init__.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1
```diff
diff --git a/v2/business_management/efb/services/__init__.py b/v2/business_management/efb/services/__init__.py
new file mode 100644
index 000000000..ccf8640cb
--- /dev/null
+++ b/v2/business_management/efb/services/__init__.py
@@ -0,0 +1 @@
+from .payroll import get_payroll_summary
\ No newline at end of file
```

### v2/business_management/efb/services/payroll.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,52
```diff
diff --git a/v2/business_management/efb/services/payroll.py b/v2/business_management/efb/services/payroll.py
new file mode 100644
index 000000000..d671db888
--- /dev/null
+++ b/v2/business_management/efb/services/payroll.py
@@ -0,0 +1,52 @@
+from decimal import Decimal
+from django.db.models import Sum
+from v2.business_management.efb.models import Employee, PaidSalary
+
+
+def get_payroll_summary(user, business_id, period=None, period_end=None, month=None, year=None):
+    paid_salaries = PaidSalary.objects.filter(user=user)
+
+    if not period and not month and not year:
```

### v2/business_management/efb/tasks.py
**Changes:** 1 additions, file deletions
- **Lines:** -690 +689,0
- **Lines:** -692,6 +690,0
- **Lines:** -714,6 +706,0
- **Lines:** -721 +707,0
- **Lines:** -723 +708,0
- **Lines:** -729 +714
- **Lines:** -731 +715,0
```diff
diff --git a/v2/business_management/efb/tasks.py b/v2/business_management/efb/tasks.py
index 6a8bd5a2a..e63b1a549 100644
--- a/v2/business_management/efb/tasks.py
+++ b/v2/business_management/efb/tasks.py
@@ -687,14 +687,7 @@ def sub_account_invitation_email(name, email, activation_link):
     content = (
         f"Hi {name},<br><br>"
         "You've been granted access to <strong>Expedier for Business</strong>.<br><br>"
-
         "To get started, please activate your account by clicking the link below:<br><br>"
-
-        f"<a href='{activation_link}' "
-        "style='color:#1a73e8; text-decoration:none; font-weight:600;'>"
-        "Accept yYour Invitation</a><br><br>"
-
```

### v2/business_management/efb/tests.py
**Changes:** 1 additions, file deletions
- **Lines:** -43,0 +44
- **Lines:** -57 +58,3
- **Lines:** -74,0 +78
- **Lines:** -75,0 +80,6
- **Lines:** -2009,0 +2020,226
- **Lines:** -2053,0 +2290,385
```diff
diff --git a/v2/business_management/efb/tests.py b/v2/business_management/efb/tests.py
index 7d2ab2343..b7a04404e 100644
--- a/v2/business_management/efb/tests.py
+++ b/v2/business_management/efb/tests.py
@@ -41,6 +41,7 @@ from account.models import (
 from wallet.models import Wallet
 from location.models import Country
 from currency.models import Currency, ExchangeRate
+from currency.models import CurrencyTransactionLimit
 from transaction.models import Transaction
 from factories.base import (
     FileFactory, CurrencyFactory,
@@ -54,7 +55,9 @@ from v2.business_management.efb.serializers import (
 )
 from v2.business_management.efb.models import (
```

### v2/business_management/efb/urls.py
**Changes:** 1 additions, file deletions
- **Lines:** -43,0 +44
- **Lines:** -54,0 +56
- **Lines:** -65,0 +68,5
```diff
diff --git a/v2/business_management/efb/urls.py b/v2/business_management/efb/urls.py
index ad0428a44..21bb187b6 100644
--- a/v2/business_management/efb/urls.py
+++ b/v2/business_management/efb/urls.py
@@ -41,6 +41,7 @@ efb_patterns = [
     path("business/create-invoice", views.InvoiceViewsets.as_view({'post': 'create_invoice'}), name='create-invoice'),
     path("business/invoices", views.InvoiceViewsets.as_view({'get': 'invoices'}), name='get-invoices'),
     path("business/update-invoice/<str:invoice_id>", views.InvoiceViewsets.as_view({'put': 'update_invoice'}), name='update-invoices'),
+    path("business/set-transaction-auth", views.SetRBATransactionAuthorizationView.as_view(), name="set-transaction-auth"),
 
     path("business/default-invoice-details", views.InvoiceViewsets.as_view({'get': 'default_invoice_details'}), name='get_details'),
     path("business/generate-pdf-invoice/<str:invoice_id>/", views.InvoiceViewsets.as_view({'get': 'generate_pdf'}), name='invoice_pdf_view'),
@@ -52,6 +53,7 @@ efb_patterns = [
     path("business/delete-employee", views.EmployeeViewSets.as_view({'delete': 'delete_employee'}), name='employee-delete'),
     path("business/pay-salary", views.PaySalaryViewSets.as_view({'post': 'create'}), name='pay'),
```

### v2/business_management/efb/views.py
**Changes:** 1 additions, file deletions
- **Lines:** -4,0 +5
- **Lines:** -34,0 +36
- **Lines:** -54 +56,15
- **Lines:** -62 +78,2
- **Lines:** -72,0 +90
- **Lines:** -89,2 +107,8
- **Lines:** -1019,0 +1044,51
- **Lines:** -1562,2 +1637,24
- **Lines:** -1565,0 +1663,6
- **Lines:** -1567 +1670,7
- **Lines:** -1584,6 +1692,0
- **Lines:** -1591 +1694,12
- **Lines:** -1593 +1706,0
- **Lines:** -1625 +1738,47
- **Lines:** -1693 +1851,0
- **Lines:** -1695 +1853,164
```diff
diff --git a/v2/business_management/efb/views.py b/v2/business_management/efb/views.py
index ab85274ee..a76afe047 100644
--- a/v2/business_management/efb/views.py
+++ b/v2/business_management/efb/views.py
@@ -2,6 +2,7 @@ import uuid
 import boto3
 import logging
 import json
+from decimal import Decimal
 from typing import Any, Union
 from datetime import timedelta, datetime, timezone as dt_timezone
 from collections import defaultdict
@@ -32,6 +33,7 @@ from rest_framework import viewsets, throttling
 
 from account.models import Currency, User, ExternalUserAccountTypeVerificationFile, ExternalUserAccountTypeVerification, UserAccountType
```

### v2/entity_management/dcp_payment.py
**Changes:** 1 additions, file deletions
- **Lines:** -495,5 +495,45
```diff
diff --git a/v2/entity_management/dcp_payment.py b/v2/entity_management/dcp_payment.py
index 3860ea928..8c0ad5b83 100644
--- a/v2/entity_management/dcp_payment.py
+++ b/v2/entity_management/dcp_payment.py
@@ -492,11 +492,51 @@ class DDTDataHandler:
         DateOfBirth: Optional[str]
         Email: Optional[str]
 
-    def __post_init__(self):
-        for field in ("Name", "MiddleName", "LastName"):
-            value = getattr(self, field)
-            if value:
-                setattr(self, field, value[:30])
+        def __post_init__(self):
+            """
```

### v2/entity_management/tests.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,62
```diff
diff --git a/v2/entity_management/tests.py b/v2/entity_management/tests.py
new file mode 100644
index 000000000..907e479c0
--- /dev/null
+++ b/v2/entity_management/tests.py
@@ -0,0 +1,62 @@
+import unittest
+from v2.entity_management.dcp_payment import DDTDataHandler
+
+class UpdateDDTRequestTestCase(unittest.TestCase):
+    def test_name_truncation(self):
+        # Create an UpdateDDTRequest with names longer than 30 characters
+        long_name = "A" * 40
+        long_middle_name = "B" * 50
+        long_last_name = "C" * 35
```

### v2/integration_management/dcp_configuration.py
**Changes:** 1 additions, file deletions
- **Lines:** -344 +344
- **Lines:** -382 +382,4
```diff
diff --git a/v2/integration_management/dcp_configuration.py b/v2/integration_management/dcp_configuration.py
index 22e0dbeb9..274f9f9b8 100644
--- a/v2/integration_management/dcp_configuration.py
+++ b/v2/integration_management/dcp_configuration.py
@@ -341,7 +341,7 @@ class DDTClient:
             idempotency_key: Optional[str] = None,
     ) -> DDTDataHandler.ItemUpdateResponse:
         """Update DDT owner information using the /Ddt/Update endpoint."""
-        if not ddt_owner_id:
+        if ddt_owner_id is None:
             raise ValueError("DDT owner ID is required")
 
         if not name:
@@ -379,7 +379,10 @@ class DDTClient:
         }
```

### v2/integration_management/paga_client.py
**Changes:** 1 additions, file deletions
- **Lines:** -189,0 +190
- **Lines:** -191,0 +193,6
```diff
diff --git a/v2/integration_management/paga_client.py b/v2/integration_management/paga_client.py
index 5907a331a..9ca4ee59c 100644
--- a/v2/integration_management/paga_client.py
+++ b/v2/integration_management/paga_client.py
@@ -187,8 +187,15 @@ class PagaPayerDetails:
     payerName: Optional[str] = None
     payerBankName: Optional[str] = None
     payerBankAccountNumber: Optional[str] = None
+    payerAccountNumber: Optional[str] = None
     narration: Optional[str] = None
 
+    def __post_init__(self):
+        if self.payerBankAccountNumber and not self.payerAccountNumber:
+            self.payerAccountNumber = self.payerBankAccountNumber
+        elif self.payerAccountNumber and not self.payerBankAccountNumber:
```

### v2/user_management/efb_subaccounts.py
**Changes:** 1 additions, file deletions
- **Lines:** -2,0 +3
- **Lines:** -5,0 +7
- **Lines:** -8,0 +11
- **Lines:** -10 +13,8
- **Lines:** -17,0 +28,6
- **Lines:** -18,0 +35,7
- **Lines:** -33,5 +56,7
- **Lines:** -43 +68
- **Lines:** -45,4 +70,9
- **Lines:** -51 +81
- **Lines:** -57 +87
- **Lines:** -103 +133
- **Lines:** -106,0 +137,5
- **Lines:** -110 +145,8
- **Lines:** -143,0 +186,7
- **Lines:** -148,0 +198
- **Lines:** -153 +203
- **Lines:** -162,0 +213,3
- **Lines:** -172,0 +226,3
- **Lines:** -181 +237,63
- **Lines:** -183,0 +302,7
- **Lines:** -208,2 +333,179
```diff
diff --git a/v2/user_management/efb_subaccounts.py b/v2/user_management/efb_subaccounts.py
index f8c211d57..e064b9569 100644
--- a/v2/user_management/efb_subaccounts.py
+++ b/v2/user_management/efb_subaccounts.py
@@ -1,13 +1,23 @@
 import uuid
 import logging
+from decimal import Decimal
 from django.conf import settings
 from django.utils import timezone
 from datetime import timedelta
+from django.core.exceptions import ObjectDoesNotExist
 from django.contrib.auth import get_user_model
 from django.shortcuts import get_object_or_404
 from django.db import transaction as db_transaction
```

### v2/user_management/repositories.py
**Changes:** 1 additions, file deletions
- **Lines:** -7,0 +8,2
- **Lines:** -41,0 +44,11
- **Lines:** -72,0 +86,29
```diff
diff --git a/v2/user_management/repositories.py b/v2/user_management/repositories.py
index be64a70c0..4523131a2 100644
--- a/v2/user_management/repositories.py
+++ b/v2/user_management/repositories.py
@@ -5,6 +5,8 @@ from django.db import transaction
 from django.shortcuts import get_object_or_404
 
 from account.models import Profile
+from v2.business_management.efb.choices import SUBACCOUNT_STATUS_REMOVED
+from v2.business_management.efb.models import SubAccountPermission
 from v2.user_management.interfaces import UserRepositoryInterface
 
 
@@ -39,6 +41,17 @@ class UserRepository(UserRepositoryInterface):
             raise ValueError("A secondary user cannot create another secondary user.")
```

### v2/user_management/subaccount_access.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,54
```diff
diff --git a/v2/user_management/subaccount_access.py b/v2/user_management/subaccount_access.py
new file mode 100644
index 000000000..b6ecc0670
--- /dev/null
+++ b/v2/user_management/subaccount_access.py
@@ -0,0 +1,54 @@
+from rest_framework.exceptions import AuthenticationFailed
+
+from v2.business_management.efb.choices import (
+    SUBACCOUNT_STATUS_ACTIVE,
+    SUBACCOUNT_STATUS_DEACTIVATED,
+    SUBACCOUNT_STATUS_REMOVED,
+)
+from v2.business_management.efb.models import SubAccountPermission
+
```

### v2/user_management/tests/test_unified_transfer_endpoints.py
**Changes:** 1 additions, file deletions
- **Lines:** -66,0 +67,8
- **Lines:** -1482,0 +1491,49
```diff
diff --git a/v2/user_management/tests/test_unified_transfer_endpoints.py b/v2/user_management/tests/test_unified_transfer_endpoints.py
index 5c21b8b73..0678d9e40 100644
--- a/v2/user_management/tests/test_unified_transfer_endpoints.py
+++ b/v2/user_management/tests/test_unified_transfer_endpoints.py
@@ -64,6 +64,14 @@ class UnifiedTransferEndpointTests(APITestCase):
             "status": "active"
         }
 
+        self.patcher_ddt_serializer = patch(
+            'account.serializers.serializers.DDTAssignmentService'
+        )
+        self.mock_ddt_serializer = self.patcher_ddt_serializer.start()
+        self.mock_ddt_serializer.return_value.get_user_provisioning_status.return_value = {
+            "status": "active"
+        }
```

### v2/user_management/transactions/entities.py
**Changes:** 1 additions, file deletions
- **Lines:** -154,0 +155,3
- **Lines:** -163 +166,2
- **Lines:** -166 +170,2
- **Lines:** -168 +173
- **Lines:** -171 +176,2
```diff
diff --git a/v2/user_management/transactions/entities.py b/v2/user_management/transactions/entities.py
index 169258b72..fbce5801f 100644
--- a/v2/user_management/transactions/entities.py
+++ b/v2/user_management/transactions/entities.py
@@ -152,6 +152,9 @@ class UnifiedTransactionEntity:
         Validates the transaction entity, creates destination wallet if needed,
         and checks if the user has sufficient funds including fees.
         """
+        if not user.profile.verify_transaction_pin(self.transaction_pin):
+            raise InvalidRequestException({'detail': 'Incorrect transaction pin'})
+
         from currency.models import CurrencyTransactionLimit
 
         # 1. Logic Errors
@@ -160,15 +163,18 @@ class UnifiedTransactionEntity:
```

### v2/user_management/transactions/services.py
**Changes:** 1 additions, file deletions
- **Lines:** -377 +377,2
- **Lines:** -380,2 +381,4
- **Lines:** -384 +387,2
```diff
diff --git a/v2/user_management/transactions/services.py b/v2/user_management/transactions/services.py
index 70b4e9fef..a24aafae2 100644
--- a/v2/user_management/transactions/services.py
+++ b/v2/user_management/transactions/services.py
@@ -374,14 +374,18 @@ class UnifiedValidationService:
         transfer_fee = Decimal('0.0')
 
         from currency.models import CurrencyTransactionLimit
-        source_limit = CurrencyTransactionLimit.objects.filter(
+        user_verified = self.user.profile.is_verified()
+        source_limit = CurrencyTransactionLimit.get_resolved_limit(
             account_type=account_type,
             currency=source_currency,
-        ).order_by('-for_verified_user').first()
-        dest_limit = CurrencyTransactionLimit.objects.filter(
```

### v2/user_management/transactions/utils.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,88
```diff
diff --git a/v2/user_management/transactions/utils.py b/v2/user_management/transactions/utils.py
new file mode 100644
index 000000000..57d736882
--- /dev/null
+++ b/v2/user_management/transactions/utils.py
@@ -0,0 +1,88 @@
+from typing import Optional, Dict, Any
+import logging
+
+from django.db.models import Q
+from account.models import UserBankAccount
+from wallet.models import (
+    DDTAssignment,
+    DDTAssignmentStatus,
+)
```

### v2/user_management/transactions/views.py
**Changes:** 1 additions, file deletions
- **Lines:** -28,0 +29
- **Lines:** -58,0 +60,16
```diff
diff --git a/v2/user_management/transactions/views.py b/v2/user_management/transactions/views.py
index 116e3186f..74a5d4969 100644
--- a/v2/user_management/transactions/views.py
+++ b/v2/user_management/transactions/views.py
@@ -26,6 +26,7 @@ from v2.user_management.transactions.services import (
     UnifiedValidationService,
     BeneficiaryManagementService,
 )
+from v2.user_management.transactions.utils import check_and_intercept_internal_transfer
 
 
 class UnifiedTransferView(APIView):
@@ -56,6 +57,22 @@ class UnifiedTransferView(APIView):
 
         entity = serializer.to_entity()
```

### v2/virtual_account_management/ddt_service.py
**Changes:** 1 additions, file deletions
- **Lines:** -1348,4 +1348,7
- **Lines:** -1353,2 +1356,41
- **Lines:** -1405,0 +1448,10
```diff
diff --git a/v2/virtual_account_management/ddt_service.py b/v2/virtual_account_management/ddt_service.py
index ffa00044c..6c37cbc5c 100644
--- a/v2/virtual_account_management/ddt_service.py
+++ b/v2/virtual_account_management/ddt_service.py
@@ -1345,13 +1345,55 @@ class DDTAssignmentService:
         if self.needs_new_ddt_request():
             self._enqueue_provisioning_task()
 
-        available_ddt = (
-            DDTAssignment.objects
-            .filter(
-                status=DDTAssignmentStatus.UNASSIGNED
-            )
-            .first()
-        )
```

### v2/virtual_account_management/ddt_tasks.py
**Changes:** 1 additions, file deletions
- **Lines:** -294,0 +295,81
- **Lines:** -365 +446
```diff
diff --git a/v2/virtual_account_management/ddt_tasks.py b/v2/virtual_account_management/ddt_tasks.py
index d9abe19be..9f29c2055 100644
--- a/v2/virtual_account_management/ddt_tasks.py
+++ b/v2/virtual_account_management/ddt_tasks.py
@@ -292,6 +292,87 @@ class DDTTask:
 
             raise Exception(f"DDT provisioning failed after {self.max_retries} retries: {str(e)}")
 
+    @staticmethod
+    @shared_task(
+        bind=True
+    )
+    def validate_ddt_inventory(self, batch_size: int = 50) -> dict:
+        """
+        Celery task to validate UNASSIGNED DDT accounts periodically.
```

### wallet/admin.py
**Changes:** 1 additions, file deletions
- **Lines:** -255,0 +256,25
```diff
diff --git a/wallet/admin.py b/wallet/admin.py
index 845922820..f9b19a06c 100755
--- a/wallet/admin.py
+++ b/wallet/admin.py
@@ -253,3 +253,28 @@ class DDTAssignmentAdmin(admin.ModelAdmin):
     def wallet_id_display(self, obj):
         return obj.wallet_id
 
+
+@admin.register(DDTConfiguration)
+class DDTConfigurationAdmin(admin.ModelAdmin):
+    list_display = (
+        "id",
+        "auto_provisioning_enabled",
+        "minimum_unassigned_threshold",
```

### wallet/management/commands/assign_ddt.py
**Changes:** 1 additions, file deletions
- **Lines:** -0,0 +1,56
```diff
diff --git a/wallet/management/commands/assign_ddt.py b/wallet/management/commands/assign_ddt.py
new file mode 100644
index 000000000..fe7e4dc46
--- /dev/null
+++ b/wallet/management/commands/assign_ddt.py
@@ -0,0 +1,56 @@
+import logging
+from django.core.management.base import BaseCommand, CommandError
+from django.contrib.auth import get_user_model
+from wallet.models import Wallet
+from v2.virtual_account_management.ddt_service import DDTAssignmentService
+
+logger = logging.getLogger(__name__)
+User = get_user_model()
+
```

### wallet/models.py
**Changes:** 1 additions, file deletions
- **Lines:** -667,0 +668,14
```diff
diff --git a/wallet/models.py b/wallet/models.py
index 6fd38d59c..5d3806706 100755
--- a/wallet/models.py
+++ b/wallet/models.py
@@ -665,6 +665,20 @@ class DDTAssignment(models.Model):
         self.status = DDTAssignmentStatus.ACTIVE
         self.save(update_fields=['status', 'updated_at'])
 
+    def mark_cancelled(self, reason: str = "") -> None:
+        """Mark DDT as cancelled (e.g. invalid on external service)."""
+        self.status = DDTAssignmentStatus.CANCELLED
+        self.save(update_fields=['status', 'updated_at'])
+        
+        # Log the cancellation
+        DDTTransactionLog.log_transaction(
```

### wallet/serializers.py
**Changes:** 1 additions, file deletions
- **Lines:** -83 +83,2
- **Lines:** -86 +87,2
```diff
diff --git a/wallet/serializers.py b/wallet/serializers.py
index 111a5c953..b7d1c6a63 100755
--- a/wallet/serializers.py
+++ b/wallet/serializers.py
@@ -80,10 +80,12 @@ class WalletSerializerIn(
         
         if user and currency:
             account_type = user.profile.account_type
-            limit = CurrencyTransactionLimit.objects.filter(
+            user_verified = user.profile.is_verified()
+            limit = CurrencyTransactionLimit.get_resolved_limit(
                 account_type=account_type,
                 currency=currency,
-            ).order_by('-for_verified_user').first()
+                for_verified_user=user_verified
```

### wallet/tests.py
**Changes:** 1 additions, file deletions
- **Lines:** -1680,0 +1681,53
```diff
diff --git a/wallet/tests.py b/wallet/tests.py
index 63cee8c3c..ea5ac1c66 100755
--- a/wallet/tests.py
+++ b/wallet/tests.py
@@ -1678,6 +1678,59 @@ class DDTIntegrationTestCase(DDTAssignmentServiceTestCase):
         self.assertIsNotNone(assignment)
         self.assertEqual(assignment.wallet_id, wallet.id)
 
+
+class DDTTaskValidationTestCase(DDTAssignmentServiceTestCase):
+    """Test cases for periodic DDT task validation."""
+
+    def test_validate_ddt_inventory_task(self):
+        """Test the validate_ddt_inventory Celery task."""
+        from v2.virtual_account_management.ddt_tasks import DDTTask
```

### wallet/views.py
**Changes:** 1 additions, file deletions
- **Lines:** -1047,0 +1048,9
- **Lines:** -1049,10 +1058
```diff
diff --git a/wallet/views.py b/wallet/views.py
index b4eff0a39..7d9460242 100755
--- a/wallet/views.py
+++ b/wallet/views.py
@@ -1045,17 +1045,17 @@ class DDTUserUpdateView(generics.GenericAPIView):
         wallet_id = validated_data["wallet_id"]
         user = request.user
 
+        extra = {
+            "user_id": user.id,
+            "wallet_id": wallet_id,
+            "email": validated_data["email"],
+            "has_name": "name"
+                        in validated_data,
+            "has_last_name": "last_name"
```

