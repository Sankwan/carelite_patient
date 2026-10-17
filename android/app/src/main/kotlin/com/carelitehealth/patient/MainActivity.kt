package com.carelitehealth.patient

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's fingerprint
// prompt is an AndroidX BiometricPrompt, which needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity()
