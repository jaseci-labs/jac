import from jaclang.toolchains.store { Artifact }

glob JDK_VERSION: str = "21.0.12.1+1",
     JDK_ARTIFACTS: dict[str, Artifact] = {
         "linux-x64": Artifact(
             "temurin-jdk",
             JDK_VERSION,
             "linux-x64",
             "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz",
             "ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94"
         ),
         "linux-aarch64": Artifact(
             "temurin-jdk",
             JDK_VERSION,
             "linux-aarch64",
             "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.12.1_1.tar.gz",
             "23e37e026f12f3e706f18938ff611db3032d075b09d0879a25d06718c773e223"
         ),
         "mac-x64": Artifact(
             "temurin-jdk",
             JDK_VERSION,
             "mac-x64",
             "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_mac_hotspot_21.0.12.1_1.tar.gz",
             "44db0f08196daf19a47f90d13388b0c943b67663cb537f998fe29e836fa842ce"
         ),
         "mac-aarch64": Artifact(
             "temurin-jdk",
             JDK_VERSION,
             "mac-aarch64",
             "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.12.1_1.tar.gz",
             "3623232f33a9c3baadf304480b2535f9a3cba8a58d42ecbb438ba267315d9998"
         ),
         "windows-x64": Artifact(
             "temurin-jdk",
             JDK_VERSION,
             "windows-x64",
             "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip",
             "f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e"
         ),
         "windows-aarch64": Artifact(
             "temurin-jdk",
             JDK_VERSION,
             "windows-aarch64",
             "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_aarch64_windows_hotspot_21.0.12.1_1.zip",
             "ccf2e51f527d542a70ba5794a600d3aac04b4e967950e227834c7566cb1bec7b"
         ),

     },
     ANDROID_TOOLS_VERSION: str = "15859902",
     ANDROID_ARTIFACTS: dict[str, Artifact] = {
         "linux-x64": Artifact(
             "android-command-line-tools",
             ANDROID_TOOLS_VERSION,
             "linux-x64",
             "https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip",
             "4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
         ),
         "mac-x64": Artifact(
             "android-command-line-tools",
             ANDROID_TOOLS_VERSION,
             "mac-x64",
             "https://dl.google.com/android/repository/commandlinetools-mac_x86_64-15859902_latest.zip",
             "c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3"
         ),
         "mac-aarch64": Artifact(
             "android-command-line-tools",
             ANDROID_TOOLS_VERSION,
             "mac-aarch64",
             "https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip",
             "835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e"
         ),
         "windows-x64": Artifact(
             "android-command-line-tools",
             ANDROID_TOOLS_VERSION,
             "windows-x64",
             "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip",
             "90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a"
         ),

     },
     PATCHELF_ARTIFACTS: dict[str, Artifact] = {
         "linux-x64": Artifact(
             "patchelf",
             "0.17.2.4",
             "linux-x64",
             "https://files.pythonhosted.org/packages/7e/19/f7821ef31aab01fa7dc8ebe697ece88ec4f7a0fdd3155dab2dfee4b00e5c/patchelf-0.17.2.4-py3-none-manylinux1_x86_64.manylinux_2_5_x86_64.musllinux_1_1_x86_64.whl",
             "d9b35ebfada70c02679ad036407d9724ffe1255122ba4ac5e4be5868618a5689"
         ),
         "linux-aarch64": Artifact(
             "patchelf",
             "0.17.2.4",
             "linux-aarch64",
             "https://files.pythonhosted.org/packages/d1/50/107fea848ecfd851d473b079cab79107487d72c4c3cdb25b9d2603a24ca2/patchelf-0.17.2.4-py3-none-manylinux2014_aarch64.manylinux_2_17_aarch64.musllinux_1_1_aarch64.whl",
             "2931a1b5b85f3549661898af7bf746afbda7903c7c9a967cfc998a3563f84fad"
         ),

     };

glob RUBY_VERSION: str = "4.0.6_2";
glob RUBY_ARTIFACTS: dict[str, Artifact] = {
         "mac-aarch64": Artifact(
             "portable-ruby",
             RUBY_VERSION,
             "mac-aarch64",
             "https://ghcr.io/v2/homebrew/core/portable-ruby/blobs/sha256:1643bb83d705f0c5e34445af151bb064bdf984081eff18a9646466b8fdd104db",
             "1643bb83d705f0c5e34445af151bb064bdf984081eff18a9646466b8fdd104db",
             headers={"Authorization": "Bearer QQ=="}
         ),
         "mac-x64": Artifact(
             "portable-ruby",
             RUBY_VERSION,
             "mac-x64",
             "https://ghcr.io/v2/homebrew/core/portable-ruby/blobs/sha256:33e2f1e2877739c45e4b4b4f5e13d46826b5933fc2bf80966263eb43f1ad2af8",
             "33e2f1e2877739c45e4b4b4f5e13d46826b5933fc2bf80966263eb43f1ad2af8",
             headers={"Authorization": "Bearer QQ=="}
         ),

     };

glob NODE_VERSION: str = "v22.23.2";
glob NODE_ARTIFACTS: dict[str, Artifact] = {
         "linux-x64": Artifact(
             "node",
             NODE_VERSION,
             "linux-x64",
             "https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-x64.tar.xz",
             "d60acfe00a2932254bb0ad20e01b0d74397a0875595de719654b214f4b03f307"
         ),
         "linux-aarch64": Artifact(
             "node",
             NODE_VERSION,
             "linux-aarch64",
             "https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-arm64.tar.xz",
             "fff4078c5def658577f92c88db7db3bc0072924bfb93fe52c1e744a54e94abb8"
         ),
         "mac-x64": Artifact(
             "node",
             NODE_VERSION,
             "mac-x64",
             "https://nodejs.org/dist/v22.23.2/node-v22.23.2-darwin-x64.tar.gz",
             "58e99022c2ff89395576cc7fd4d98cea24bb68081475d5f88b801ee8729fb026"
         ),
         "mac-aarch64": Artifact(
             "node",
             NODE_VERSION,
             "mac-aarch64",
             "https://nodejs.org/dist/v22.23.2/node-v22.23.2-darwin-arm64.tar.gz",
             "61130f394c1630d211dd50aecc4353d379480f36d3ac913cd85dbba1aed585c6"
         ),
         "windows-x64": Artifact(
             "node",
             NODE_VERSION,
             "windows-x64",
             "https://nodejs.org/dist/v22.23.2/node-v22.23.2-win-x64.zip",
             "1177b4137ba5adaa56354ae40f1080c7450e8ae09cecb47da459d1c52ac99f97"
         ),
         "windows-aarch64": Artifact(
             "node",
             NODE_VERSION,
             "windows-aarch64",
             "https://nodejs.org/dist/v22.23.2/node-v22.23.2-win-arm64.zip",
             "fec025a6da31757e3b6af84c5a1628e9d38442ca99a2161091d78f2fcfa35ef3"
         ),

     };
