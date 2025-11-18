# Jac RPG Game (jac_impl)

A sample RPG game built in the [Jac language](https://github.com/jaseci-labs/jaseci) with Pygame for rendering and optional LLM integration via **byllm**.

---

## Clone Only the Required Folder
This game lives inside the `jac/examples/rpg_game/jac_impl` directory of the Jaseci repository.
We’ll use **Git sparse-checkout** so you only clone this folder.

```bash
# Clone without checking out files
git clone --no-checkout https://github.com/jaseci-labs/jaseci.git
cd jaseci

# Enable sparse-checkout
git sparse-checkout init --cone

# Get only the game folder
git sparse-checkout set jac/examples/rpg_game/jac_impl

# Checkout the latest code
git checkout main
```

---

## 📦 Install Dependencies

Make sure you have **Python 3.12+** installed. Then:

```bash
# Create and activate a virtual environment (recommended)
python -m venv env
.\env\Scripts\activate   # Windows
# source env/bin/activate  # macOS/Linux

# Install required packages
pip install pygame jac-lang byllm
```

> These dependencies cover:
> - `pygame` → graphics & game loop
> - `byllm` → LLM integration in Jac
> - `jac-lang` → Jac language runtime

---

## 🔑 Set Your API Keys

### For OpenAI (default model: `gpt-4o`)

1. Open your **terminal** (PowerShell/Git Bash on Windows, Terminal on macOS/Linux).
2. In the terminal, type this command and press Enter:
   ```powershell
   $env:OPENAI_API_KEY = "sk-your_openai_api_key"
   ```
3. Replace `sk-your_openai_api_key` with your actual OpenAI API key.
4. Keep this terminal session open and run the game from the same terminal, so the environment variable is available

### For Gemini (if you want to use it instead) or Any other Model
1. Open **`utils/level_manager.jac`**.
2. Find:
   ```jac
   glob llm = Model(model_name="gpt-4o", verbose=True);
   ```
3. Change it to:
   ```jac
   glob llm = Model(model_name="gemini/gemini-2.5-flash", verbose=True);
   ```
4. Then set your Gemini API key:
   ```powershell
   $env:GEMINI_API_KEY = "your_gemini_api_key"
   ```

---

## ▶️ Run the Game

From the folder:
```
jac/examples/rpg_game/jac_impl/jac_impl_6
```
run:

```bash
jac run main.jac
```

---

## 📁 Asset Paths

The game loads its images and fonts from:
```
jac_impl/img/
jac_impl/fonts/
```
Do **not** move these folders, or you will get "file not found" errors.

---

## 🛠 Troubleshooting

- **File not found errors** → Make sure you run `jac run main.jac` from the `jac_impl_6` folder.
- **Pygame errors** → Ensure `pygame` installed correctly: `pip show pygame`.
- **LLM errors** → Verify your API keys are set in the **same terminal session** you run the game from.

---

## 📜 License
This project follows the [Jaseci Labs license](https://github.com/jaseci-labs/jaseci/blob/main/.github/LICENSE).
