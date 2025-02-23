import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart' as ac;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

enum TextFieldInertiaDirection {
  left,
  right,
}

Interval _getInternalInterval(
  double start,
  double end,
  double externalStart,
  double externalEnd, [
  Curve curve = Curves.linear,
]) {
  return Interval(
    start + (end - start) * externalStart,
    start + (end - start) * externalEnd,
    curve: curve,
  );
}

class AnimatedTextFormField extends StatefulWidget {
  const AnimatedTextFormField({
    super.key,
    this.textFormFieldKey,
    this.interval = const Interval(0.0, 1.0),
    required this.width,
    this.userType,
    this.loadingController,
    this.inertiaController,
    this.inertiaDirection,
    this.enabled = true,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.controller,
    this.focusNode,
    this.validator,
    this.onFieldSubmitted,
    this.onSaved,
    this.autocorrect = false,
    this.autofillHints,
    this.suggestionsCallback,
    this.tooltip,
    this.possibleValues,
    this.onChanged,
    this.formFieldController,
  }) : assert(
          (inertiaController == null && inertiaDirection == null) ||
              (inertiaController != null && inertiaDirection != null),
        );

  final Key? textFormFieldKey;
  final Interval? interval;
  final AnimationController? loadingController;
  final AnimationController? inertiaController;
  final double width;
  final LoginUserType? userType;
  final bool enabled;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final SuggestionsCallback? suggestionsCallback;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final TextFieldInertiaDirection? inertiaDirection;
  final InlineSpan? tooltip;
  final List<String>? possibleValues;
  final ValueChanged<String?>? onChanged;
  final FormFieldController? formFieldController;

  @override
  State<AnimatedTextFormField> createState() => _AnimatedTextFormFieldState();
}

class _AnimatedTextFormFieldState extends State<AnimatedTextFormField> {
  late Animation<double> scaleAnimation;
  late Animation<double> sizeAnimation;
  late Animation<double> suffixIconOpacityAnimation;

  late Animation<double> fieldTranslateAnimation;
  late Animation<double> iconRotationAnimation;
  late Animation<double> iconTranslateAnimation;

  PhoneNumber? _phoneNumberInitialValue;
  TextEditingController _phoneNumberController = TextEditingController();

  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();

    widget.inertiaController?.addStatusListener(handleAnimationStatus);

    final interval = widget.interval;
    final loadingController = widget.loadingController;

    if (loadingController != null) {
      scaleAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: loadingController,
          curve: _getInternalInterval(
            0,
            .2,
            interval!.begin,
            interval.end,
            Curves.easeOutBack,
          ),
        ),
      );
      suffixIconOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: loadingController,
          curve: _getInternalInterval(.65, 1.0, interval.begin, interval.end),
        ),
      );
      _updateSizeAnimation();
    }

    final inertiaController = widget.inertiaController;
    final inertiaDirection = widget.inertiaDirection;
    final sign = inertiaDirection == TextFieldInertiaDirection.right ? 1 : -1;

    if (inertiaController != null) {
      fieldTranslateAnimation = Tween<double>(
        begin: 0.0,
        end: sign * 15.0,
      ).animate(
        CurvedAnimation(
          parent: inertiaController,
          curve: const Interval(0, .5, curve: Curves.easeOut),
          reverseCurve: Curves.easeIn,
        ),
      );
      iconRotationAnimation =
          Tween<double>(begin: 0.0, end: sign * pi / 12 /* ~15deg */).animate(
        CurvedAnimation(
          parent: inertiaController,
          curve: const Interval(.5, 1.0, curve: Curves.easeOut),
          reverseCurve: Curves.easeIn,
        ),
      );
      iconTranslateAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
        CurvedAnimation(
          parent: inertiaController,
          curve: const Interval(.5, 1.0, curve: Curves.easeOut),
          reverseCurve: Curves.easeIn,
        ),
      );
    }

    if (widget.userType == LoginUserType.intlPhone) {
      _phoneNumberInitialValue = PhoneNumber(isoCode: 'US', dialCode: '+1');
      if (widget.controller?.value.text != null) {
        try {
          final parsed = pnp.PhoneNumber.parse(widget.controller!.value.text);
          if (parsed.isValid()) {
            _phoneNumberInitialValue = PhoneNumber(
                phoneNumber: parsed.nsn,
                isoCode: parsed.isoCode.name,
                dialCode: parsed.countryCode,
            );
          }
        } on pnp.PhoneNumberException {
          // ignore
        } finally {
          widget.controller!.text = '';
        }
      }
    }
    widget.formFieldController?.addListener(handleValueChange);
    _focusNode = widget.focusNode ?? FocusNode();
  }

  void _updateSizeAnimation() {
    final interval = widget.interval!;
    final loadingController = widget.loadingController!;

    sizeAnimation = Tween<double>(
      begin: 48.0,
      end: widget.width,
    ).animate(
      CurvedAnimation(
        parent: loadingController,
        curve: _getInternalInterval(
          .2,
          1.0,
          interval.begin,
          interval.end,
          Curves.linearToEaseOut,
        ),
        reverseCurve: Curves.easeInExpo,
      ),
    );
  }

  @override
  void didUpdateWidget(AnimatedTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.width != widget.width) {
      _updateSizeAnimation();
    }
  }

  @override
  void dispose() {
    widget.inertiaController?.removeStatusListener(handleAnimationStatus);
    widget.formFieldController?.removeListener(handleValueChange);
    super.dispose();
  }

  void handleValueChange() {
    setState(() {
      if (widget.controller != null) {
        widget.controller!.text = widget.formFieldController!.value ?? '';
      }
      _phoneNumberController.text = widget.formFieldController!.value ?? '';
    });
  }

  void handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.inertiaController?.reverse();
    }
  }

  Widget? _buildInertiaAnimation(Widget? child) {
    if (widget.inertiaController == null) {
      return child;
    }

    return AnimatedBuilder(
      animation: iconTranslateAnimation,
      builder: (context, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(iconTranslateAnimation.value)
          ..rotateZ(iconRotationAnimation.value),
        child: child,
      ),
      child: child,
    );
  }

  InputDecoration _getInputDecoration(ThemeData theme) {
    return InputDecoration(
      labelText: widget.labelText,
      prefixIcon: _buildInertiaAnimation(widget.prefixIcon),
      suffixIcon: widget.suffixIcon!= null ? _buildInertiaAnimation(
        widget.loadingController != null
            ? FadeTransition(
                opacity: suffixIconOpacityAnimation,
                child: widget.suffixIcon,
              )
            : widget.suffixIcon,
      ) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget textField;
    if (widget.userType == LoginUserType.intlPhone) {
      textField = Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InternationalPhoneNumberInput(
          key: widget.textFormFieldKey,
          cursorColor: theme.primaryColor,
          focusNode: _focusNode,
          inputDecoration: _getInputDecoration(theme),
          searchBoxDecoration: const InputDecoration(
              contentPadding: EdgeInsets.only(left: 20),
              labelText: 'Search by country name or dial code'),
          keyboardType: widget.keyboardType ?? TextInputType.phone,
          onFieldSubmitted: widget.onFieldSubmitted,
          onSaved: (phoneNumber) {
            if (phoneNumber.phoneNumber == phoneNumber.dialCode) {
              widget.controller?.text = '';
            } else {
              widget.controller?.text = phoneNumber.phoneNumber ?? '';
            }
            _phoneNumberController.selection = TextSelection.collapsed(offset: _phoneNumberController.text.length);
            widget.onSaved?.call(phoneNumber.phoneNumber);
          },
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          onInputChanged: (phoneNumber) {
            if (phoneNumber.phoneNumber != null && phoneNumber.dialCode != null && phoneNumber.phoneNumber!.startsWith('+')) {
              _phoneNumberController.text = _phoneNumberController.text.replaceAll(
                RegExp('^([\\+]${phoneNumber.dialCode!.replaceAll('+', '')}[\\s]?)'),
                '',
              );
              widget.onChanged?.call(_phoneNumberController.text);
            }
            _phoneNumberController.selection = TextSelection.collapsed(offset: _phoneNumberController.text.length);
          },
          textFieldController: _phoneNumberController,
          isEnabled: widget.enabled,
          selectorConfig: SelectorConfig(
            selectorType: PhoneInputSelectorType.DIALOG,
            trailingSpace: false,
            countryComparator: (c1, c2) => int.parse(c1.dialCode!.substring(1))
                .compareTo(int.parse(c2.dialCode!.substring(1))),
          ),
          spaceBetweenSelectorAndTextField: 0,
          initialValue: _phoneNumberInitialValue,
        ),
      );
    } else if (widget.suggestionsCallback != null) {
      textField = ac.TypeAheadFormField<String>(
        key: widget.textFormFieldKey,
        textFieldConfiguration: ac.TextFieldConfiguration(
          controller: widget.controller,
          cursorColor: theme.primaryColor,
          focusNode: _focusNode,
          decoration: _getInputDecoration(theme),
          keyboardType: widget.keyboardType ?? TextInputType.text,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText,
          enabled: widget.enabled,
          autocorrect: widget.autocorrect,
        ),
        suggestionsCallback: widget.suggestionsCallback!,
        itemBuilder: (context, suggestion) {
          return ListTile(
            title: Text(suggestion),
          );
        },
        transitionBuilder: (context, suggestionsBox, controller) {
          return suggestionsBox;
        },
        onSuggestionSelected: (suggestion) {
          widget.controller?.text = suggestion;
          widget.onChanged?.call(suggestion);
        },
        validator: widget.validator,
        onSaved: widget.onSaved,
        minCharsForSuggestions: 3,
        suggestionsBoxDecoration: ac.SuggestionsBoxDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: theme.primaryColor, width: 1.5),
          ),
        ),
        autoFlipDirection: true,
        hideOnEmpty: true,
      );
      _focusNode?.addListener(() {
        if (!_focusNode!.hasFocus) {
          widget.onChanged?.call(widget.controller?.text);
        }
      });
    } else if (widget.userType == LoginUserType.dropdown) {
      textField = DropdownButtonFormField<String>(
        key: widget.textFormFieldKey,
        items: (widget.possibleValues ?? [])
            .map(
              (e) =>
              DropdownMenuItem<String>(
                value: e,
                child: Text(
                  e,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            widget.controller?.text = newValue;
          } else {
            widget.controller?.clear();
          }
          widget.onChanged?.call(newValue);
        },
        value: (widget.controller?.text.isNotEmpty ?? false)
            ? widget.controller?.text
            : null,
        decoration: _getInputDecoration(theme),
        onSaved: widget.onSaved,
        focusNode: _focusNode,
        validator: widget.validator,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        isExpanded: true,
      );
    } else {
      textField = TextFormField(
        key: widget.textFormFieldKey,
        cursorColor: theme.primaryColor,
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: _getInputDecoration(theme),
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        onFieldSubmitted: widget.onFieldSubmitted,
        onSaved: widget.onSaved,
        validator: widget.validator,
        enabled: widget.enabled,
        autocorrect: widget.autocorrect,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
      );
    }

    if (widget.tooltip != null) {
      final tooltipKey = GlobalKey<TooltipState>();
      final tooltip = Tooltip(
        key: tooltipKey,
        richMessage: widget.tooltip,
        showDuration: const Duration(seconds: 30),
        triggerMode: TooltipTriggerMode.manual,
        margin: const EdgeInsets.all(4),
        child: textField,
      );
      textField = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: tooltip,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => tooltipKey.currentState?.ensureTooltipVisible(),
            color: theme.primaryColor,
            iconSize: 28,
            icon: const Icon(Icons.info),
          )
        ],
      );
    }

    if (widget.loadingController != null) {
      textField = ScaleTransition(
        scale: scaleAnimation,
        child: AnimatedBuilder(
          animation: sizeAnimation,
          builder: (context, child) => ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: sizeAnimation.value),
            child: child,
          ),
          child: textField,
        ),
      );
    }

    if (widget.inertiaController != null) {
      textField = AnimatedBuilder(
        animation: fieldTranslateAnimation,
        builder: (context, child) => Transform.translate(
          offset: Offset(fieldTranslateAnimation.value, 0),
          child: child,
        ),
        child: textField,
      );
    }

    return textField;
  }
}

class AnimatedPasswordTextFormField extends StatefulWidget {
  const AnimatedPasswordTextFormField({
    super.key,
    this.interval = const Interval(0.0, 1.0),
    required this.animatedWidth,
    this.loadingController,
    this.inertiaController,
    this.inertiaDirection,
    this.enabled = true,
    this.labelText,
    this.keyboardType,
    this.textInputAction,
    this.controller,
    this.focusNode,
    this.validator,
    this.onFieldSubmitted,
    this.onSaved,
    this.autofillHints,
  }) : assert(
          (inertiaController == null && inertiaDirection == null) ||
              (inertiaController != null && inertiaDirection != null),
        );

  final Interval? interval;
  final AnimationController? loadingController;
  final AnimationController? inertiaController;
  final double animatedWidth;
  final bool enabled;
  final String? labelText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final TextFieldInertiaDirection? inertiaDirection;
  final Iterable<String>? autofillHints;

  @override
  State<AnimatedPasswordTextFormField> createState() =>
      _AnimatedPasswordTextFormFieldState();
}

class _AnimatedPasswordTextFormFieldState
    extends State<AnimatedPasswordTextFormField> {
  var _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedTextFormField(
      interval: widget.interval,
      loadingController: widget.loadingController,
      inertiaController: widget.inertiaController,
      width: widget.animatedWidth,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      labelText: widget.labelText,
      prefixIcon: const Icon(FontAwesomeIcons.lock, size: 20),
      suffixIcon: GestureDetector(
        onTap: () => setState(() => _obscureText = !_obscureText),
        dragStartBehavior: DragStartBehavior.down,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstCurve: Curves.easeInOutSine,
          secondCurve: Curves.easeInOutSine,
          alignment: Alignment.center,
          layoutBuilder: (Widget topChild, _, Widget bottomChild, __) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[bottomChild, topChild],
            );
          },
          firstChild: const Icon(
            Icons.visibility,
            size: 25.0,
            semanticLabel: 'show password',
          ),
          secondChild: const Icon(
            Icons.visibility_off,
            size: 25.0,
            semanticLabel: 'hide password',
          ),
          crossFadeState: _obscureText
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
        ),
      ),
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      controller: widget.controller,
      focusNode: widget.focusNode,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onSaved: widget.onSaved,
      inertiaDirection: widget.inertiaDirection,
    );
  }
}
