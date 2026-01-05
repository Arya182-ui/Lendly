import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';

/// Modern Text Field
class ModernTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  const ModernTextField({
    Key? key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _hasText = widget.controller?.text.isNotEmpty ?? false;
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (_isFocused) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    
    final borderColor = hasError 
        ? AppColors.error 
        : (_isFocused 
            ? AppColors.primary 
            : (isDark ? AppColors.borderDark : AppColors.borderLight));
    
    final bgColor = isDark 
        ? (_isFocused ? AppColors.surfaceDark : AppColors.backgroundDark)
        : (_isFocused ? Colors.white : AppColors.backgroundLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.labelMedium.copyWith(
              color: hasError 
                  ? AppColors.error 
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 2 : 1.5,
            ),
            boxShadow: _isFocused 
                ? AppShadows.colored(hasError ? AppColors.error : AppColors.primary, opacity: 0.1)
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            maxLines: widget.maxLines,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            onChanged: (value) {
              setState(() => _hasText = value.isNotEmpty);
              widget.onChanged?.call(value);
            },
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.bodyLarge.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        widget.prefixIcon,
                        color: _isFocused 
                            ? AppColors.primary 
                            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                        size: 22,
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: widget.suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: widget.suffix,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? 0 : 18,
                vertical: widget.maxLines > 1 ? 16 : 0,
              ),
              border: InputBorder.none,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Modern Search Bar
class ModernSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onFilterTap;
  final bool showFilter;
  final bool autofocus;
  final VoidCallback? onTap;
  final bool readOnly;

  const ModernSearchBar({
    Key? key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.showFilter = false,
    this.autofocus = false,
    this.onTap,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<ModernSearchBar> createState() => _ModernSearchBarState();
}

class _ModernSearchBarState extends State<ModernSearchBar> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused 
                ? AppColors.primary 
                : (isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5)),
            width: _isFocused ? 2 : 1,
          ),
          boxShadow: _isFocused ? AppShadows.medium : AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.search_rounded,
                color: _isFocused ? AppColors.primary : AppColors.textTertiaryLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.readOnly
                  ? Text(
                      widget.hint,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    )
                  : TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      readOnly: widget.readOnly,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
            ),
            if (widget.showFilter)
              GestureDetector(
                onTap: widget.onFilterTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modern Password Field with visibility toggle
class ModernPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  const ModernPasswordField({
    Key? key,
    this.controller,
    this.label,
    this.hint = 'Enter password',
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction,
  }) : super(key: key);

  @override
  State<ModernPasswordField> createState() => _ModernPasswordFieldState();
}

class _ModernPasswordFieldState extends State<ModernPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return ModernTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      errorText: widget.errorText,
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      validator: widget.validator,
      suffix: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.textTertiaryLight,
          size: 22,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
