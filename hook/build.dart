import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    const builder = RustBuilder(
      assetName: 'rhai_dart',
    );

    await builder.run(
      input: config,
      output: output,
    );
  });
}
