import 'package:flutter/material.dart';

class InputSlider extends StatefulWidget {
  final double value;
  final void Function(double v) onChanged;

  const InputSlider({Key key, @required this.value, @required this.onChanged})
      : super(key: key);

  @override
  _InputSliderState createState() => _InputSliderState();
}

class _InputSliderState extends State<InputSlider> {
  TextField sizeField;

  @override
  void initState() {
    super.initState();
    resetSizeField();
  }

  void resetSizeField() {
    sizeField = TextField(
      focusNode: FocusNode(),
      onChanged: (s) {
        double result = double.tryParse(s);
        print(result);
        if (result != null) {
          widget.onChanged(result.clamp(0.5, 1.0));
        }
      },
      onEditingComplete: () {
        sizeField.focusNode.unfocus();
        sizeField.controller.text = widget.value.toString();
      },
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      expands: false,
      autofocus: false,
      autocorrect: false,
      controller: TextEditingController(text: widget.value.toString()),
      keyboardType:
          TextInputType.numberWithOptions(decimal: true, signed: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider.adaptive(
              value: widget.value,
              min: 0.5,
              max: 1.0,
              divisions: 50,
              label: "${(widget.value * 100).round()}%",
              onChanged: (v) {
                sizeField.focusNode.unfocus();
                var value = (v * 100).roundToDouble() / 100;
                sizeField.controller.text = value.toString();
                widget.onChanged(value);
              }),
        ),
        Container(width: 20),
        Container(
          child: sizeField,
          width: 40,
        ),
      ],
    );
  }
}
