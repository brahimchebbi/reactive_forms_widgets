// Copyright 2020 Joan Pablo Jiménez Milian. All rights reserved.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'image_file.dart';

typedef Widget ImageViewBuilder(ImageFile image);
typedef Widget InputButtonBuilder(VoidCallback onPressed);
typedef void ErrorPickBuilder(ImagePickerSource source, {BuildContext context});
typedef void DeleteDialogBuilder(BuildContext context, VoidCallback onConfirm);
typedef void PopupDialogBuilder(
    BuildContext context, ImagePickCallback pickImage);
typedef void ImagePickCallback(BuildContext context, ImagePickerSource source);

enum ImagePickerSource { camera, gallery }

extension ImagePickerSourceExt on ImagePickerSource {
  ImageSource get source {
    switch (this) {
      case ImagePickerSource.camera:
        return ImageSource.camera;
      case ImagePickerSource.gallery:
        return ImageSource.gallery;
    }

    return null;
  }
}

/// A [ReactiveImagePicker] that contains a [DropdownSearch].
///
/// This is a convenience widget that wraps a [DropdownSearch] widget in a
/// [ReactiveImagePicker].
///
/// A [ReactiveForm] ancestor is required.
///
class ReactiveImagePicker extends ReactiveFormField<ImageFile> {
  /// Creates a [ReactiveImagePicker] that contains a [DropdownSearch].
  ///
  /// Can optionally provide a [formControl] to bind this widget to a control.
  ///
  /// Can optionally provide a [formControlName] to bind this ReactiveFormField
  /// to a [FormControl].
  ///
  /// Must provide one of the arguments [formControl] or a [formControlName],
  /// but not both at the same time.
  ///
  /// Can optionally provide a [validationMessages] argument to customize a
  /// message for different kinds of validation errors.
  ///
  /// Can optionally provide a [valueAccessor] to set a custom value accessors.
  /// See [ControlValueAccessor].
  ///
  /// Can optionally provide a [showErrors] function to customize when to show
  /// validation messages. Reactive Widgets make validation messages visible
  /// when the control is INVALID and TOUCHED, this behavior can be customized
  /// in the [showErrors] function.
  ///
  /// ### Example:
  /// Binds a text field.
  /// ```
  /// final form = fb.group({'email': Validators.required});
  ///
  /// ReactiveUpload(
  ///   formControlName: 'image',
  /// ),
  ///
  /// ```
  ///
  /// Binds a text field directly with a *FormControl*.
  /// ```
  /// final form = fb.group({'image': Validators.required});
  ///
  /// ReactiveUpload(
  ///   formControl: form.control('image'),
  /// ),
  ///
  /// ```
  ///
  /// Customize validation messages
  /// ```dart
  /// ReactiveUpload(
  ///   formControlName: 'image',
  ///   validationMessages: {
  ///     ValidationMessage.required: 'The image must not be empty',
  ///   }
  /// ),
  /// ```
  ///
  /// Customize when to show up validation messages.
  /// ```dart
  /// ReactiveUpload(
  ///   formControlName: 'image',
  ///   showErrors: (control) => control.invalid && control.touched && control.dirty,
  /// ),
  /// ```
  ///
  /// For documentation about the various parameters, see the [ImagePicker] class
  /// and [new ImagePicker], the constructor.
  ReactiveImagePicker({
    Key key,
    String formControlName,
    InputDecoration decoration,
    InputButtonBuilder inputBuilder,
    ImageViewBuilder imageViewBuilder,
    DeleteDialogBuilder deleteDialogBuilder,
    ErrorPickBuilder errorPickBuilder,
    PopupDialogBuilder popupDialogBuilder,
    BoxDecoration imageContainerDecoration,
    Widget editIcon,
    Widget deleteIcon,
    FormControl formControl,
    ValidationMessagesFunction validationMessages,
    ControlValueAccessor valueAccessor,
    ShowErrorsFunction showErrors,
    bool enabled = true,
  }) : super(
          key: key,
          formControl: formControl,
          formControlName: formControlName,
          valueAccessor: valueAccessor,
          validationMessages: (control) {
            final error = validationMessages?.call(control) ?? {};

            if (error?.containsKey(ImagePickerSource.camera.toString()) !=
                true) {
              error.addEntries([
                MapEntry(ImagePickerSource.camera.toString(),
                    'Error while taking image from camera')
              ]);
            }

            if (error?.containsKey(ImagePickerSource.gallery.toString()) !=
                true) {
              error.addEntries([
                MapEntry(ImagePickerSource.gallery.toString(),
                    'Error while taking image from gallery')
              ]);
            }

            return error;
          },
          showErrors: showErrors,
          builder: (ReactiveFormFieldState field) {
            final InputDecoration effectiveDecoration = (decoration ??
                    const InputDecoration())
                .applyDefaults(Theme.of(field.context).inputDecorationTheme);

            return Listener(
              onPointerDown: (_) => field.control.markAsTouched(),
              child: ImagePickerWidget(
                imageViewBuilder: imageViewBuilder,
                popupDialogBuilder: popupDialogBuilder,
                errorPickBuilder: errorPickBuilder ??
                    (ImagePickerSource source, {BuildContext context}) {
                      if (source == ImagePickerSource.camera) {
                        field.control.setErrors(<String, dynamic>{
                          ImagePickerSource.camera.toString(): true,
                        });
                      }

                      if (source == ImagePickerSource.gallery) {
                        field.control.setErrors(<String, dynamic>{
                          ImagePickerSource.gallery.toString(): true,
                        });
                      }
                    },
                inputBuilder: inputBuilder,
                imageContainerDecoration: imageContainerDecoration,
                deleteDialogBuilder: deleteDialogBuilder,
                editIcon: editIcon,
                deleteIcon: deleteIcon,
                decoration:
                    effectiveDecoration.copyWith(errorText: field.errorText),
                onChanged: field.didChange,
                value: field.value as ImageFile,
              ),
            );
          },
        );
}

class ImagePickerWidget extends StatelessWidget {
  final InputDecoration decoration;
  final BoxDecoration imageContainerDecoration;
  final Widget editIcon;
  final Widget deleteIcon;
  final InputButtonBuilder inputBuilder;
  final ImageViewBuilder imageViewBuilder;
  final DeleteDialogBuilder deleteDialogBuilder;
  final ErrorPickBuilder errorPickBuilder;
  final PopupDialogBuilder popupDialogBuilder;
  final ImageFile value;
  final bool enabled;
  final ValueChanged<ImageFile> onChanged;

  const ImagePickerWidget({
    Key key,
    this.value,
    this.enabled = true,
    this.onChanged,
    this.decoration,
    this.imageViewBuilder,
    this.inputBuilder,
    this.imageContainerDecoration,
    this.editIcon,
    this.deleteIcon,
    this.deleteDialogBuilder,
    this.errorPickBuilder,
    this.popupDialogBuilder,
  }) : super(key: key);

  void _onImageButtonPressed(
      BuildContext context, ImagePickerSource source) async {
    final picker = ImagePicker();

    try {
      final pickedFile = await picker.getImage(source: source.source);

      if (pickedFile != null) {
        onChanged(
            (value ?? ImageFile()).copyWith(image: File(pickedFile.path)));
      }
    } catch (e) {
      errorPickBuilder?.call(source, context: context);
    }
  }

  void _buildPopupMenu(BuildContext context) {
    if (popupDialogBuilder != null) {
      popupDialogBuilder(context, _onImageButtonPressed);
      return;
    }

    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (context) => Row(
        children: <Widget>[
          Expanded(
              flex: 3,
              child: Container(
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ListTile(
                        leading: Icon(Icons.photo_camera),
                        title: Text('Take photo'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _onImageButtonPressed(
                            context,
                            ImagePickerSource.camera,
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.photo),
                        title: Text('Choose from library'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _onImageButtonPressed(
                            context,
                            ImagePickerSource.gallery,
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.clear),
                        title: Text('Cancel'),
                        onTap: Navigator.of(context).pop,
                      )
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _handleDelete(BuildContext context) {
    final onConfirm = () => onChanged(
          value.copyWith(image: null, localImage: null),
        );

    if (deleteDialogBuilder != null) {
      deleteDialogBuilder(context, onConfirm);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete image"),
          content: Text("This action could not be undone"),
          actions: [
            FlatButton(
              child: Text("CLOSE"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FlatButton(
              child: Text("CONFIRM"),
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildImage(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: imageContainerDecoration ??
          BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          imageViewBuilder?.call(value) ??
              Container(
                height: 250,
                child: _ImageView(image: value),
              ),
          if (enabled)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  onPressed: () => _buildPopupMenu(context),
                  icon: editIcon ?? Icon(Icons.edit),
                ),
                if (value.image != null || value.localImage != null)
                  SizedBox(width: 8),
                if (value.image != null || value.localImage != null)
                  IconButton(
                    onPressed: () => _handleDelete(context),
                    icon: deleteIcon ?? Icon(Icons.delete),
                  )
              ],
            )
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return OutlineButton.icon(
      onPressed: () => _buildPopupMenu(context),
      icon: Icon(Icons.add, color: Color(0xFF00A7E1)),
      label: Text('Pick image'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: decoration,
      child: value?.isNotEmpty == true
          ? _buildImage(context)
          : inputBuilder?.call(() => _buildPopupMenu(context)) ??
              _buildInput(context),
    );
  }
}

class _ImageView extends StatelessWidget {
  final ImageFile image;

  const _ImageView({Key key, this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (image.image != null) {
      return Image.file(
        image.image,
        fit: BoxFit.cover,
      );
    }

    if (image.localImage != null) {
      final file = File(image.localImage);
      return Image.memory(
        file.readAsBytesSync(),
        fit: BoxFit.cover,
      );
    }

    if (image.imageUrl != null) {
      return Image.network(image.imageUrl);
    }

    return Container();
  }
}
