part of auth_card_builder;

class _ConfirmSignupCard extends StatefulWidget {
  _ConfirmSignupCard({
    super.key,
    required this.onBack,
    required this.onSubmitCompleted,
    this.loginAfterSignUp = true,
    required this.loadingController,
    required this.keyboardType,
    this.initialCode,
  });

  final bool loginAfterSignUp;
  final VoidCallback onBack;
  final VoidCallback onSubmitCompleted;
  final AnimationController loadingController;
  final TextInputType? keyboardType;
  String? initialCode;

  @override
  _ConfirmSignupCardState createState() => _ConfirmSignupCardState();
}

class _ConfirmSignupCardState extends State<_ConfirmSignupCard>
    with SingleTickerProviderStateMixin, CodeAutoFill {
  final GlobalKey<FormState> _formRecoverKey = GlobalKey();

  // List of animation controller for every field
  late AnimationController _fieldSubmitController;

  var _isSubmitting = false;
  var _code = '';

  final TextEditingController _codeTextController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _fieldSubmitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    listenForCode();
    ConfirmationListeners.instance.register((code) => _enterCode(code, ''));
  }

  @override
  void dispose() {
    _fieldSubmitController.dispose();
    cancel();
    ConfirmationListeners.instance.clear();
    super.dispose();
  }

  Future<bool> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formRecoverKey.currentState!.validate()) {
      return false;
    }
    final auth = Provider.of<Auth>(context, listen: false);
    final messages = Provider.of<LoginMessages>(context, listen: false);

    _formRecoverKey.currentState!.save();
    await _fieldSubmitController.forward();
    setState(() => _isSubmitting = true);
    final error = await auth.onConfirmSignup!(
      _code,
      LoginData(
        name: auth.email,
        password: auth.password,
      ),
    );

    if (error != null) {
      showErrorToast(context, messages.flushbarTitleError, error);
      setState(() => _isSubmitting = false);
      await _fieldSubmitController.reverse();
      return false;
    }

    showSuccessToast(
      context,
      messages.flushbarTitleSuccess,
      messages.confirmSignupSuccess,
    );
    setState(() => _isSubmitting = false);
    await _fieldSubmitController.reverse();

    if (!widget.loginAfterSignUp) {
      auth.mode = AuthMode.login;
      widget.onBack();
      return false;
    }

    widget.onSubmitCompleted();
    return true;
  }

  Future<bool> _resendCode() async {
    FocusScope.of(context).unfocus();

    final auth = Provider.of<Auth>(context, listen: false);
    final messages = Provider.of<LoginMessages>(context, listen: false);

    await _fieldSubmitController.forward();
    setState(() => _isSubmitting = true);
    final error = await auth.onResendCode!(
      SignupData.fromSignupForm(
        name: auth.email,
        password: auth.password,
        termsOfService: auth.getTermsOfServiceResults(),
      ),
    );

    if (error != null) {
      showErrorToast(context, messages.flushbarTitleError, error);
      setState(() => _isSubmitting = false);
      await _fieldSubmitController.reverse();
      return false;
    }

    showSuccessToast(
      context,
      messages.flushbarTitleSuccess,
      messages.resendCodeSuccess,
    );
    setState(() => _isSubmitting = false);
    await _fieldSubmitController.reverse();
    return true;
  }

  Widget _buildConfirmationCodeField(double width, LoginMessages messages) {
    return AnimatedTextFormField(
      loadingController: widget.loadingController,
      width: width,
      labelText: messages.confirmationCodeHint,
      prefixIcon: const Icon(FontAwesomeIcons.solidCircleCheck),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (value) => _submit(),
      validator: (value) {
        if (value!.isEmpty) {
          return messages.confirmationCodeValidationError;
        }
        return null;
      },
      onSaved: (value) => _code = value!,
      keyboardType: widget.keyboardType,
      controller: _codeTextController,
    );
  }

  Widget _buildResendCode(ThemeData theme, LoginMessages messages) {
    return ScaleTransition(
      scale: widget.loadingController,
      child: MaterialButton(
        onPressed: !_isSubmitting ? _resendCode : null,
        child: Text(
          messages.resendCodeButton,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildConfirmButton(ThemeData theme, LoginMessages messages) {
    return ScaleTransition(
      scale: widget.loadingController,
      child: AnimatedButton(
        controller: _fieldSubmitController,
        text: messages.confirmSignupButton,
        onPressed: !_isSubmitting ? _submit : null,
      ),
    );
  }

  Widget _buildBackButton(ThemeData theme, LoginMessages messages) {
    return ScaleTransition(
      scale: widget.loadingController,
      child: MaterialButton(
        onPressed: !_isSubmitting ? widget.onBack : null,
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textColor: theme.primaryColor,
        child: Text(messages.goBackButton),
      ),
    );
  }

  @override
  void codeUpdated() {
    final actual = _codeTextController.text;
    _enterCode(code, actual);
  }

  void _enterCode(String? code, String actual) {
    _codeTextController.text = code ?? actual;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isSubmitting) {
        _submit();
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = Provider.of<LoginMessages>(context, listen: false);
    final deviceSize = MediaQuery.of(context).size;
    final cardWidth = min(deviceSize.width * 0.75, 360.0);
    const cardPadding = 16.0;
    final textFieldWidth = cardWidth - cardPadding * 2;

    if (widget.initialCode != null) {
      widget.initialCode = null;
      Future.delayed(Duration(seconds: 1), () => _enterCode(widget.initialCode, ''));
    }

    return FittedBox(
      child: Card(
        child: Container(
          padding: const EdgeInsets.only(
            left: cardPadding,
            top: cardPadding + 10.0,
            right: cardPadding,
            bottom: cardPadding,
          ),
          width: cardWidth,
          alignment: Alignment.center,
          child: Form(
            key: _formRecoverKey,
            child: Column(
              children: <Widget>[
                ScaleTransition(
                  scale: widget.loadingController,
                  child: Text(
                    messages.confirmSignupIntro,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 20),
                _buildConfirmationCodeField(textFieldWidth, messages),
                const SizedBox(height: 10),
                _buildResendCode(theme, messages),
                _buildConfirmButton(theme, messages),
                _buildBackButton(theme, messages),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
