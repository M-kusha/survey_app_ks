package com.echomeet.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (rather than FlutterActivity) is required by
// local_auth: the biometric prompt is a fragment and needs a FragmentActivity
// host to attach to.
class MainActivity : FlutterFragmentActivity()
