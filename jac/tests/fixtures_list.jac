"""Fixed lists of test files for deterministic test discovery.

This module contains fixed lists of files for testing, replacing the dynamic
discovery mechanisms (os.walk, rglob) that previously scanned directories.
This ensures tests are deterministic and don't pick up new files automatically.

To add new test files, manually add them to the appropriate list below.
"""

# Fixed list of .jac files for micro suite testing.
# These files were discovered as of the initial snapshot and should be
# manually updated when new test files are added.
glob MICRO_JAC_FILES: list[str] = [
         "examples/chess/chess.impl.jac",
         "examples/chess/chess.jac",
         "examples/day_planner/auth/components/AuthForm.cl.jac",
         "examples/day_planner/auth/components/Header.cl.jac",
         "examples/day_planner/auth/components/IngredientItem.cl.jac",
         "examples/day_planner/auth/components/ShoppingPanel.cl.jac",
         "examples/day_planner/auth/components/TaskItem.cl.jac",
         "examples/day_planner/auth/components/TasksPanel.cl.jac",
         "examples/day_planner/auth/frontend.cl.jac",
         "examples/day_planner/auth/main.jac",
         "examples/day_planner/basic/main.jac",
         "examples/day_planner/walkers/components/AuthForm.cl.jac",
         "examples/day_planner/walkers/components/Header.cl.jac",
         "examples/day_planner/walkers/components/IngredientItem.cl.jac",
         "examples/day_planner/walkers/components/ShoppingPanel.cl.jac",
         "examples/day_planner/walkers/components/TaskItem.cl.jac",
         "examples/day_planner/walkers/components/TasksPanel.cl.jac",
         "examples/day_planner/walkers/frontend.cl.jac",
         "examples/day_planner/walkers/main.jac",
         "examples/littleX/components/AuthForm.cl.jac",
         "examples/littleX/components/Button.cl.jac",
         "examples/littleX/components/ChannelsTab.cl.jac",
         "examples/littleX/components/Composer.cl.jac",
         "examples/littleX/components/ExploreTab.cl.jac",
         "examples/littleX/components/FeedTab.cl.jac",
         "examples/littleX/components/MobileNav.cl.jac",
         "examples/littleX/components/ProfileTab.cl.jac",
         "examples/littleX/components/RightSidebar.cl.jac",
         "examples/littleX/components/Sidebar.cl.jac",
         "examples/littleX/components/TweetCard.cl.jac",
         "examples/littleX/components/WelcomeBanner.cl.jac",
         "examples/littleX/frontend.cl.jac",
         "examples/littleX/frontend.impl.jac",
         "examples/littleX/main.jac",
         "examples/littleX/server.jac",
         "examples/littleX/test_littlex.jac",
         "examples/mini_todo/bench_local.jac",
         "examples/mini_todo/main.jac",
         "examples/mini_todo/test_local.jac"
     ],
     # Fixed list of Python files in the jaclang package for py2jac testing.
     JACLANG_PYTHON_FILES: list[str] = [
         "jaclang/__init__.py",
         "jaclang/__main__.py",
         "jaclang/compiler/__init__.py",
         "jaclang/compiler/passes/__init__.py",
         "jaclang/compiler/passes/ecmascript/__init__.py",
         "jaclang/compiler/passes/main/__init__.py",
         "jaclang/compiler/passes/tool/__init__.py",
         "jaclang/compiler/type_system/__init__.py",
         "jaclang/meta_importer.py",
         "jaclang/jac0core/__init__.py",
         "jaclang/jac0core/passes/__init__.py",
         "jaclang/jac0core/passes/ast_gen/__init__.py",
         "jaclang/utils/__init__.py"
     ];
