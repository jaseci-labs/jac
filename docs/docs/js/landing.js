
document.addEventListener('DOMContentLoaded', function () {
    // Hide loading overlay
    setTimeout(() => {
        document.getElementById('loading-overlay').style.opacity = '0';
        setTimeout(() => {
            document.getElementById('loading-overlay').style.display = 'none';
        }, 500);
    }, 1500);

    // Typing animation
    const phrases = [
        "# Write once, scale everywhere",
        "# AI-first programming language",
        "# Object-Spatial Programming",
        "# Cloud-native by design"
    ];
    let phraseIndex = 0;
    let charIndex = 0;
    let isDeleting = false;
    const typingElement = document.getElementById('typing-text');

    function typeWriter() {
        const currentPhrase = phrases[phraseIndex];

        if (isDeleting) {
            typingElement.textContent = currentPhrase.substring(0, charIndex - 1);
            charIndex--;
        } else {
            typingElement.textContent = currentPhrase.substring(0, charIndex + 1);
            charIndex++;
        }

        let typeSpeed = isDeleting ? 50 : 100;

        if (!isDeleting && charIndex === currentPhrase.length) {
            typeSpeed = 2000; // Pause at end
            isDeleting = true;
        } else if (isDeleting && charIndex === 0) {
            isDeleting = false;
            phraseIndex = (phraseIndex + 1) % phrases.length;
            typeSpeed = 500; // Pause before next phrase
        }

        setTimeout(typeWriter, typeSpeed);
    }

    typeWriter();

    // Floating particles
    function createParticle() {
        const particle = document.createElement('div');
        particle.className = 'particle';
        particle.style.left = Math.random() * 100 + '%';
        particle.style.animationDuration = (Math.random() * 3 + 3) + 's';
        particle.style.animationDelay = Math.random() * 2 + 's';
        document.getElementById('particles-container').appendChild(particle);

        // Remove particle after animation
        setTimeout(() => {
            particle.remove();
        }, 8000);
    }

    // Create particles periodically
    setInterval(createParticle, 300);

    // Progress bar
    function updateProgressBar() {
        const scrollTop = window.pageYOffset;
        const docHeight = document.body.scrollHeight - window.innerHeight;
        const scrollPercent = (scrollTop / docHeight) * 100;
        document.getElementById('progress-bar').style.width = scrollPercent + '%';
    }

    window.addEventListener('scroll', updateProgressBar);

    // Mouse follower
    const mouseFollower = document.getElementById('mouse-follower');
    let mouseX = 0, mouseY = 0;
    let followerX = 0, followerY = 0;

    document.addEventListener('mousemove', (e) => {
        mouseX = e.clientX;
        mouseY = e.clientY;
    });

    function animateFollower() {
        const dx = mouseX - followerX;
        const dy = mouseY - followerY;

        followerX += dx * 0.1;
        followerY += dy * 0.1;

        mouseFollower.style.left = followerX + 'px';
        mouseFollower.style.top = followerY + 'px';

        requestAnimationFrame(animateFollower);
    }

    animateFollower();

    // Enhanced Interactive Code Demo
    const demoData = {
        byllm: {
            title: "AI-Integrated Programming with byLLM",
            code: `<span class="jac-comment"># AI Integration with byLLM - No Prompt Engineering Required! 🤖</span>

<span class="jac-keyword">import</span> <span class="jac-keyword">from</span> <span class="jac-variable">byllm</span>.<span class="jac-variable">llms</span> { <span class="jac-node">OpenAI</span> }

<span class="jac-comment"># Initialize AI model</span>
<span class="jac-keyword">glob</span> <span class="jac-variable">llm</span> = <span class="jac-node">OpenAI</span>(<span class="jac-variable">model_name</span>=<span class="jac-string">"gpt-4o"</span>);

<span class="jac-comment"># Define AI-powered functions with just signatures!</span>
<span class="jac-keyword">def</span> <span class="jac-function">translate</span>(<span class="jac-variable">text</span>: <span class="jac-keyword">str</span>, <span class="jac-variable">target_language</span>: <span class="jac-keyword">str</span>) <span class="jac-operator">-></span> <span class="jac-keyword">str</span> <span class="jac-keyword">by</span> <span class="jac-variable">llm</span>();

<span class="jac-keyword">def</span> <span class="jac-function">analyze_sentiment</span>(<span class="jac-variable">text</span>: <span class="jac-keyword">str</span>) <span class="jac-operator">-></span> <span class="jac-keyword">str</span> <span class="jac-keyword">by</span> <span class="jac-variable">llm</span>(<span class="jac-variable">method</span>=<span class="jac-string">'Reason'</span>);

<span class="jac-keyword">with</span> <span class="jac-keyword">entry</span> {
    <span class="jac-variable">customer_feedback</span> = <span class="jac-string">"I'm really disappointed with the product quality."</span>;

    <span class="jac-comment"># AI reasons through sentiment analysis step-by-step</span>
    <span class="jac-variable">sentiment</span> = <span class="jac-function">analyze_sentiment</span>(<span class="jac-variable">customer_feedback</span>);
    <span class="jac-function">print</span>(<span class="jac-string">f"Customer sentiment: {sentiment}"</span>);

    <span class="jac-comment"># Translate the sentiment analysis to Spanish</span>
    <span class="jac-variable">translated</span> = <span class="jac-function">translate</span>(<span class="jac-variable">sentiment</span>, <span class="jac-string">"Spanish"</span>);
    <span class="jac-function">print</span>(<span class="jac-string">f"Translated result: {translated}"</span>);
}`,
            output: [
                { type: 'info', text: '🧠 Analyzing sentiment with step-by-step reasoning...' },
                { type: 'success', text: 'Customer sentiment: Negative. The customer expresses disappointment with product quality, which clearly indicates dissatisfaction.' },
                { type: 'info', text: '🌍 Translating sentiment analysis to Spanish...' },
                { type: 'success', text: 'Translated result: Negativo. El cliente expresa decepción con la calidad del producto, lo que indica claramente insatisfacción.' },
                { type: 'info', text: '✨ AI analysis completed successfully!' }
            ]
        },
        rpg: {
            title: "AI-Generated Game Levels",
            code: `<span class="jac-comment"># RPG Game with AI-Generated Maps 🎮</span>

<span class="jac-keyword">import</span> <span class="jac-keyword">from</span> <span class="jac-variable">byllm</span>.<span class="jac-variable">llms</span> { <span class="jac-node">OpenAI</span> }

<span class="jac-keyword">glob</span> <span class="jac-variable">llm</span> = <span class="jac-node">OpenAI</span>(<span class="jac-variable">model_name</span>=<span class="jac-string">"gpt-4o"</span>);

<span class="jac-comment"># Game data structures</span>
<span class="jac-keyword">obj</span> <span class="jac-node">Position</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">x</span>: <span class="jac-keyword">int</span>, <span class="jac-variable">y</span>: <span class="jac-keyword">int</span>;
}

<span class="jac-keyword">obj</span> <span class="jac-node">Wall</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">start_pos</span>: <span class="jac-node">Position</span>, <span class="jac-variable">end_pos</span>: <span class="jac-node">Position</span>;
}

<span class="jac-keyword">obj</span> <span class="jac-node">Level</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">name</span>: <span class="jac-keyword">str</span>, <span class="jac-variable">difficulty</span>: <span class="jac-keyword">int</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">width</span>: <span class="jac-keyword">int</span>, <span class="jac-variable">height</span>: <span class="jac-keyword">int</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">num_wall</span>: <span class="jac-keyword">int</span>, <span class="jac-variable">num_enemies</span>: <span class="jac-keyword">int</span>;
}

<span class="jac-keyword">obj</span> <span class="jac-node">Map</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">level</span>: <span class="jac-node">Level</span>, <span class="jac-variable">walls</span>: <span class="jac-keyword">list</span>[<span class="jac-node">Wall</span>];
    <span class="jac-keyword">has</span> <span class="jac-variable">enemies</span>: <span class="jac-keyword">list</span>[<span class="jac-node">Position</span>];
    <span class="jac-keyword">has</span> <span class="jac-variable">player_pos</span>: <span class="jac-node">Position</span>;
}

<span class="jac-comment"># AI-powered level generation!</span>
<span class="jac-keyword">def</span> <span class="jac-function">create_next_level</span>(<span class="jac-variable">last_levels</span>: <span class="jac-keyword">list</span>[<span class="jac-node">Level</span>], <span class="jac-variable">difficulty</span>: <span class="jac-keyword">int</span>,
    <span class="jac-variable">level_width</span>: <span class="jac-keyword">int</span>, <span class="jac-variable">level_height</span>: <span class="jac-keyword">int</span>) <span class="jac-operator">-></span> <span class="jac-node">Level</span> <span class="jac-keyword">by</span> <span class="jac-variable">llm</span>();

<span class="jac-keyword">def</span> <span class="jac-function">create_next_map</span>(<span class="jac-variable">level</span>: <span class="jac-node">Level</span>) <span class="jac-operator">-></span> <span class="jac-node">Map</span> <span class="jac-keyword">by</span> <span class="jac-variable">llm</span>();

<span class="jac-keyword">with</span> <span class="jac-keyword">entry</span> {
    <span class="jac-variable">prev_levels</span> = [];
    <span class="jac-variable">difficulty</span> = 2;

    <span class="jac-comment"># Generate level with AI</span>
    <span class="jac-variable">new_level</span> = <span class="jac-function">create_next_level</span>(<span class="jac-variable">prev_levels</span>, <span class="jac-variable">difficulty</span>, 10, 10);
    <span class="jac-function">print</span>(<span class="jac-string">f"Generated level: {new_level.name}, Difficulty: {new_level.difficulty}"</span>);

    <span class="jac-comment"># Generate map layout with AI</span>
    <span class="jac-variable">game_map</span> = <span class="jac-function">create_next_map</span>(<span class="jac-variable">new_level</span>);
    <span class="jac-function">print</span>(<span class="jac_string">f"Map created with {len(game_map.walls)} walls and {len(game_map.enemies)} enemies"</span>);
    <span class="jac-function">print</span>(<span class="jac_string">f"Player starting position: ({game_map.player_pos.x}, {game_map.player_pos.y})"</span>);
}`,
            output: [
                { type: 'info', text: '🎮 Initializing game engine...' },
                { type: 'info', text: '🧠 AI is generating level design...' },
                { type: 'success', text: 'Generated level: The Dark Cavern, Difficulty: 2' },
                { type: 'info', text: '🧠 AI is creating map layout...' },
                { type: 'success', text: 'Map created with 5 walls and 3 enemies' },
                { type: 'success', text: 'Player starting position: (2, 2)' },
                { type: 'info', text: '🎲 Game level ready for play!' }
            ]
        },
        cloud: {
            title: "Cloud-Native Apps with Jac",
            code: `<span class="jac-comment"># Zero-Config Cloud Deployment ☁️</span>

<span class="jac-comment"># Define data models for a simple task manager</span>
<span class="jac-keyword">node</span> <span class="jac-node">User</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">name</span>: <span class="jac-keyword">str</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">email</span>: <span class="jac-keyword">str</span>;
}

<span class="jac-keyword">node</span> <span class="jac-node">Task</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">title</span>: <span class="jac-keyword">str</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">description</span>: <span class="jac-keyword">str</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">completed</span>: <span class="jac-keyword">bool</span> = <span class="jac-keyword">false</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">created_at</span>: <span class="jac-keyword">str</span> = <span class="jac-function">datetime.now</span>().<span class="jac-function">strftime</span>(<span class="jac-string">"%Y-%m-%d %H:%M:%S"</span>);
}

<span class="jac-keyword">edge</span> <span class="jac-edge">HasTask</span> {}

<span class="jac-comment"># API endpoints - auto-generated REST</span>
<span class="jac-keyword">walker</span> <span class="jac-walker">create_task</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">title</span>: <span class="jac-keyword">str</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">description</span>: <span class="jac-keyword">str</span>;

    <span class="jac-keyword">can</span> <span class="jac-function">create</span> <span class="jac-keyword">with</span> <span class="jac-node">User</span> <span class="jac-keyword">entry</span> {
        <span class="jac-variable">task</span> = <span class="jac-node">Task</span>(<span class="jac-variable">title</span>=<span class="jac-variable">self</span>.<span class="jac-variable">title</span>, <span class="jac-variable">description</span>=<span class="jac-variable">self</span>.<span class="jac-variable">description</span>);
        <span class="jac-variable">here</span> <span class="jac-operator">+>:</span><span class="jac-edge">HasTask</span><span class="jac-operator">:+></span> <span class="jac-variable">task</span>;
        <span class="jac-keyword">report</span> { <span class="jac_string">"success"</span>: <span class="jac-keyword">true</span>, <span class="jac_string">"task_id"</span>: <span class="jac-variable">task</span>.<span class="jac-variable">jid</span> };
    }
}

<span class="jac-keyword">walker</span> <span class="jac-walker">get_tasks</span> {
    <span class="jac-keyword">can</span> <span class="jac-function">list</span> <span class="jac-keyword">with</span> <span class="jac-node">User</span> <span class="jac-keyword">entry</span> {
        <span class="jac-variable">tasks</span> = [];
        <span class="jac-keyword">for</span> <span class="jac-variable">task</span> <span class="jac-keyword">in</span> [<span class="jac-variable">here</span> <span class="jac-operator">-></span>:<span class="jac-edge">HasTask</span><span class="jac-operator">-></span>] {
            <span class="jac-variable">tasks</span>.<span class="jac-function">append</span>({
                <span class="jac_string">"id"</span>: <span class="jac-variable">task</span>.<span class="jac-variable">jid</span>,
                <span class="jac_string">"title"</span>: <span class="jac-variable">task</span>.<span class="jac-variable">title</span>,
                <span class="jac_string">"completed"</span>: <span class="jac-variable">task</span>.<span class="jac-variable">completed</span>
            });
        }
        <span class="jac-keyword">report</span> <span class="jac-variable">tasks</span>;
    }
}

<span class="jac-comment"># Deploy with: jac start taskapp.jac</span>
<span class="jac-comment"># Instantly get: REST API, auth, auto-scaling</span>

<span class="jac-keyword">with</span> <span class="jac-keyword">entry</span> {
    <span class="jac-function">print</span>(<span class="jac-string">"🌐 Task Manager API Ready!"</span>);
    <span class="jac-function">print</span>(<span class="jac-string">"✅ POST /create_task - Create a new task"</span>);
    <span class="jac-function">print</span>(<span class="jac_string">"✅ GET /get_tasks - List all tasks"</span>);
}`,
            output: [
                { type: 'success', text: '🌐 Task Manager API Ready!' },
                { type: 'success', text: '✅ POST /create_task - Create a new task' },
                { type: 'success', text: '✅ GET /get_tasks - List all tasks' },
                { type: 'info', text: '🚀 Server running at http://localhost:8000' },
                { type: 'info', text: '📚 API docs available at /docs' },
                { type: 'success', text: '⚡ Auto-scaling enabled - 0 to 1000 instances' },
                { type: 'success', text: '💾 Persistent storage configured and ready' }
            ]
        },
        littlex: {
            title: "LittleX - A Twitter-like Platform",
            code: `<span class="jac-comment"># LittleX - Build a Twitter clone in 50 lines! 🐦</span>

<span class="jac-comment"># Define User and Tweet data models</span>
<span class="jac-keyword">node</span> <span class="jac-node">Profile</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">username</span>: <span class="jac-keyword">str</span> = <span class="jac-string">""</span>;

    <span class="jac-keyword">can</span> <span class="jac-function">update</span> <span class="jac-keyword">with</span> <span class="jac-variable">update_profile</span> <span class="jac-keyword">entry</span>;
    <span class="jac-keyword">can</span> <span class="jac-function">follow</span> <span class="jac-keyword">with</span> <span class="jac-variable">follow_request</span> <span class="jac-keyword">entry</span>;
}

<span class="jac-keyword">node</span> <span class="jac-node">Tweet</span> {
    <span class="jac-keyword">has</span> <span class="jac-variable">content</span>: <span class="jac-keyword">str</span>;
    <span class="jac-keyword">has</span> <span class="jac-variable">created_at</span>: <span class="jac-keyword">str</span> = <span class="jac-function">datetime.datetime.now</span>().<span class="jac-function">strftime</span>(<span class="jac-string">"%Y-%m-%d %H:%M:%S"</span>);

    <span class="jac-keyword">can</span> <span class="jac-function">like_tweet</span> <span class="jac-keyword">with</span> <span class="jac-variable">like_tweet</span> <span class="jac-keyword">entry</span>;
    <span class="jac-keyword">can</span> <span class="jac-function">comment</span> <span class="jac-keyword">with</span> <span class="jac-variable">comment_tweet</span> <span class="jac-keyword">entry</span>;
}

<span class="jac-keyword">edge</span> <span class="jac-edge">Follow</span> {}
<span class="jac-keyword">edge</span> <span class="jac-edge">Post</span> {}

<span class="jac-comment"># User profile walker</span>
<span class="jac-keyword">walker</span> <span class="jac-walker">visit_profile</span> {
    <span class="jac-keyword">can</span> <span class="jac-function">visit_profile</span> <span class="jac-keyword">with</span> <span class="jac-keyword">root</span> <span class="jac-keyword">entry</span>;
}

<span class="jac-comment"># Tweet creation</span>
<span class="jac-keyword">walker</span> <span class="jac-walker">create_tweet</span>(<span class="jac-walker">visit_profile</span>) {
    <span class="jac-keyword">has</span> <span class="jac-variable">content</span>: <span class="jac-keyword">str</span>;
    <span class="jac-keyword">can</span> <span class="jac-function">tweet</span> <span class="jac-keyword">with</span> <span class="jac-node">Profile</span> <span class="jac-keyword">entry</span>;
}

<span class="jac-comment"># Feed generator</span>
<span class="jac-keyword">walker</span> <span class="jac-walker">load_feed</span>(<span class="jac-walker">visit_profile</span>) {
    <span class="jac-keyword">has</span> <span class="jac-variable">results</span>: <span class="jac-keyword">list</span> = [];
    <span class="jac-keyword">can</span> <span class="jac-function">load</span> <span class="jac-keyword">with</span> <span class="jac-node">Profile</span> <span class="jac-keyword">entry</span>;
}

<span class="jac-keyword">with</span> <span class="jac-keyword">entry</span> {
    <span class="jac-comment"># Simulate users and tweets</span>
    <span class="jac-variable">alice</span> = <span class="jac-node">Profile</span>(<span class="jac-variable">username</span>=<span class="jac-string">"alice"</span>);
    <span class="jac-variable">bob</span> = <span class="jac-node">Profile</span>(<span class="jac-variable">username</span>=<span class="jac-string">"bob"</span>);

    <span class="jac-comment"># Alice follows Bob</span>
    <span class="jac-variable">alice</span> <span class="jac-operator">+>:</span><span class="jac-edge">Follow</span><span class="jac-operator">:+></span> <span class="jac-variable">bob</span>;

    <span class="jac-comment"># Bob posts a tweet</span>
    <span class="jac-variable">tweet</span> = <span class="jac-node">Tweet</span>(<span class="jac-variable">content</span>=<span class="jac-string">"Hello from LittleX!"</span>);
    <span class="jac-variable">bob</span> <span class="jac-operator">+>:</span><span class="jac-edge">Post</span><span class="jac-operator">:+></span> <span class="jac-variable">tweet</span>;

    <span class="jac-function">print</span>(<span class="jac-string">"✅ LittleX platform initialized!"</span>);
    <span class="jac-function">print</span>(<span class="jac_string">f"👤 Users: {alice.username}, {bob.username}"</span>);
    <span class="jac-function">print</span>(<span class="jac_string">f"🐦 Latest tweet: {tweet.content}"</span>);
}`,
            output: [
                { type: 'info', text: '🚀 Initializing LittleX social platform...' },
                { type: 'info', text: '👤 Creating user profiles...' },
                { type: 'info', text: '🔗 Establishing follow relationship...' },
                { type: 'info', text: '📝 Creating tweet...' },
                { type: 'success', text: '✅ LittleX platform initialized!' },
                { type: 'success', text: '👤 Users: alice, bob' },
                { type: 'success', text: '🐦 Latest tweet: Hello from LittleX!' },
                { type: 'info', text: '💾 Graph database ready for more social connections!' }
            ]
        }
    };

    // Enhanced demo functionality with fake execution
    const demoTabs = document.querySelectorAll('.demo-tab');
    const demoCode = document.getElementById('demo-code');
    const demoOutput = document.getElementById('demo-output');
    let currentDemo = 'byllm';

    function showDemo(demoKey) {
        currentDemo = demoKey;
        const demo = demoData[demoKey];

        // Update active tab
        demoTabs.forEach(tab => {
            tab.classList.remove('active');
            if (tab.dataset.demo === demoKey) {
                tab.classList.add('active');
            }
        });

        // Animate code change with null checks
        if (demoCode) {
            demoCode.style.opacity = '0';
            demoCode.style.transform = 'translateY(10px)';
        }

        setTimeout(() => {
            if (demoCode) {
                demoCode.innerHTML = `<pre><code>${demo.code}</code></pre>`;
                demoCode.style.opacity = '1';
                demoCode.style.transform = 'translateY(0)';
            }
            // Clear output
            if (demoOutput) {
                demoOutput.innerHTML = '<div class="output-line info-line">Click "Run" to execute this program ▶️</div>';
            }
        }, 300);
    }

    function showOutput(outputLines) {
        demoOutput.innerHTML = '';

        outputLines.forEach((line, index) => {
            setTimeout(() => {
                const outputLine = document.createElement('div');
                outputLine.className = `output-line ${line.type}-line`;
                outputLine.textContent = line.text;
                demoOutput.appendChild(outputLine);

                // Auto-scroll to bottom
                demoOutput.scrollTop = demoOutput.scrollHeight;
            }, index * 400);
        });
    }

    // Enhanced fake execution
    window.runCurrentDemo = function () {
        const demo = demoData[currentDemo];
        const codePanel = demoCode.parentElement;
        const indicator = document.createElement('div');
        indicator.className = 'execution-indicator active';
        indicator.textContent = 'EXECUTING';
        codePanel.appendChild(indicator);

        // Add executing class
        demoCode.classList.add('executing');

        // Show execution start
        demoOutput.innerHTML = '<div class="output-line info-line">🔄 Compiling Jac program...</div>';

        setTimeout(() => {
            demoOutput.innerHTML += '<div class="output-line info-line">✅ Compilation successful</div>';
        }, 800);

        setTimeout(() => {
            demoOutput.innerHTML += '<div class="output-line info-line">🚀 Executing program...</div>';
        }, 1200);

        setTimeout(() => {
            // Remove execution indicator
            indicator.remove();
            demoCode.classList.remove('executing');

            // Show actual output
            demoOutput.innerHTML = '';
            showOutput(demo.output);
        }, 1800);
    };

    demoTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            showDemo(tab.dataset.demo);
        });
    });

    // Initialize first demo
    showDemo('byllm');

    // FIXED: Carousel functionality
    function initCarousel(carouselId, prevBtnId, nextBtnId, indicatorsId) {
        const carousel = document.getElementById(carouselId);
        const wrapper = carousel.querySelector('.carousel-wrapper');
        const prevBtn = document.getElementById(prevBtnId);
        const nextBtn = document.getElementById(nextBtnId);
        const indicators = document.getElementById(indicatorsId);
        const indicatorElements = indicators.querySelectorAll('.indicator');

        let currentSlide = 0;
        const totalSlides = wrapper.children.length;

        function updateCarousel() {
            const translateX = -currentSlide * 100;
            wrapper.style.transform = `translateX(${translateX}%)`;

            // Update indicators
            indicatorElements.forEach((indicator, index) => {
                indicator.classList.toggle('active', index === currentSlide);
            });

            // Update button states
            prevBtn.disabled = currentSlide === 0;
            nextBtn.disabled = currentSlide === totalSlides - 1;
        }

        function nextSlide() {
            if (currentSlide < totalSlides - 1) {
                currentSlide++;
                updateCarousel();
            }
        }

        function prevSlide() {
            if (currentSlide > 0) {
                currentSlide--;
                updateCarousel();
            }
        }

        function goToSlide(index) {
            currentSlide = index;
            updateCarousel();
        }

        // Event listeners
        prevBtn.addEventListener('click', prevSlide);
        nextBtn.addEventListener('click', nextSlide);

        indicatorElements.forEach((indicator, index) => {
            indicator.addEventListener('click', () => goToSlide(index));
        });

        // Auto-play functionality
        let autoPlayInterval;

        function startAutoPlay() {
            autoPlayInterval = setInterval(() => {
                if (currentSlide < totalSlides - 1) {
                    nextSlide();
                } else {
                    currentSlide = 0;
                    updateCarousel();
                }
            }, 4000);
        }

        function stopAutoPlay() {
            clearInterval(autoPlayInterval);
        }

        // Start auto-play and pause on hover
        startAutoPlay();
        carousel.addEventListener('mouseenter', stopAutoPlay);
        carousel.addEventListener('mouseleave', startAutoPlay);

        // Initialize
        updateCarousel();

        // Touch/swipe support for mobile
        let startX = 0;
        let currentX = 0;
        let isDragging = false;

        carousel.addEventListener('touchstart', (e) => {
            startX = e.touches[0].clientX;
            isDragging = true;
            stopAutoPlay();
        });

        carousel.addEventListener('touchmove', (e) => {
            if (!isDragging) return;
            currentX = e.touches[0].clientX;
        });

        carousel.addEventListener('touchend', () => {
            if (!isDragging) return;
            isDragging = false;

            const deltaX = startX - currentX;
            if (Math.abs(deltaX) > 50) {
                if (deltaX > 0) {
                    nextSlide();
                } else {
                    prevSlide();
                }
            }

            startAutoPlay();
        });
    }

    // Initialize carousels
    initCarousel('getting-started-carousel', 'prev-getting-started', 'next-getting-started', 'indicators-getting-started');
    initCarousel('features-carousel', 'prev-features', 'next-features', 'indicators-features');

    // Scroll animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    // const observer = new IntersectionObserver((entries) => {
    //     entries.forEach(entry => {
    //         if (entry.isIntersecting) {
    //             entry.target.classList.add('visible');

    //             // Animate stats
    //             if (entry.target.classList.contains('animated-stat')) {
    //                 const statNumber = entry.target.querySelector('.stat-number');
    //                 const targetValue = parseInt(statNumber.dataset.count);
    //                 animateCount(statNumber, targetValue);
    //             }
    //         }
    //     });
    // }, observerOptions);

    // Observe all animate-on-scroll elements
    // document.querySelectorAll('.animate-on-scroll, .animated-stat').forEach(el => {
    //     observer.observe(el);
    // });

    // Animated counting
    function animateCount(element, target) {
        let current = 0;
        const increment = target / 60;
        const timer = setInterval(() => {
            current += increment;
            if (current >= target) {
                element.textContent = target;
                clearInterval(timer);
            } else {
                element.textContent = Math.floor(current);
            }
        }, 30);
    }

    // Enhanced feature card interactions
    document.querySelectorAll('.feature-card').forEach(card => {
        card.addEventListener('mouseenter', () => {
            const icon = card.querySelector('.feature-icon');
            icon.style.animation = 'bounce 0.6s ease';
        });

        card.addEventListener('mouseleave', () => {
            const icon = card.querySelector('.feature-icon');
            icon.style.animation = '';
        });
    });

    // Add bounce keyframes
    const style = document.createElement('style');
    style.textContent = `
                @keyframes bounce {
                    0%, 20%, 60%, 100% { transform: translateY(0) scale(1); }
                    40% { transform: translateY(-10px) scale(1.1); }
                    80% { transform: translateY(-5px) scale(1.05); }
                }
            `;
    document.head.appendChild(style);

    // Fetch GitHub stars and forks from local JSON file
    fetch('../assets/github_stats.json')
        .then(response => response.json())
        .then(data => {
            // Check for the "jaseci-labs/jaseci" key and get stars/forks
            let stats = data["jaseci-labs/jaseci"];
            console.log('GitHub stats:', stats);
            if (stats) {
                document.querySelectorAll('#github-stars').forEach(el => el.textContent = stats.stars);
                document.querySelectorAll('#github-forks').forEach(el => el.textContent = stats.forks);
                document.querySelectorAll('#github-contributors').forEach(el => el.textContent = stats.total_contributors);
            } else {
                document.querySelectorAll('#github-stars').forEach(el => el.textContent = 'N/A');
                document.querySelectorAll('#github-forks').forEach(el => el.textContent = 'N/A');
                document.querySelectorAll('#github-contributors').forEach(el => el.textContent = 'N/A');
            }
        })
        .catch(() => {
            document.querySelectorAll('#github-stars').forEach(el => el.textContent = 'N/A');
            document.querySelectorAll('#github-forks').forEach(el => el.textContent = 'N/A');
            document.querySelectorAll('#github-contributors').forEach(el => el.textContent = 'N/A');
        });
});
// Make sure to include highlight.js in your HTML as described

const tabsData = [
    {
        tagline: "Jac Supersets Python",
        summary: `Jac is a drop-in replacement for Python and supersets Python, much like Typescript supersets Javascript or C++ supersets C. It maintains full interoperability with the Python ecosystem, introducing new features to minimize complexity and accelerate AI application development. We also provide library mode.`,
        filename: "distance_calculator.jac",
        code: `
import math;
import from random { uniform }

def calc_distance(x1: float, y1: float, x2: float, y2: float) -> float {
return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
}

with entry { # Generate random points
(x1, y1) = (uniform(0, 10), uniform(0, 10));
(x2, y2) = (uniform(0, 10), uniform(0, 10));

    distance = calc_distance(x1, y1, x2, y2);
    area = math.pi * (distance / 2) ** 2;

    print("Distance:", round(distance, 2), ", Circle area:", round(area, 2));

}`,
        codeLang: "python",
        output: `Distance: 5.79 , Circle area: 26.35`,
        link: "https://www.jac-lang.org/jac_book/chapter_1/#comparison-with-python-and-traditional-languages"
    },
    {
        tagline: "Programming Abstractions for AI",
        summary: `Using "by" keyword to seamlessly integrate models into your development. No need for prompt engineering or interpret model outputs`,
        filename: "ai_sentiment_analysis.jac",
        code: `
# AI Integration with byLLM - No Prompt Engineering Required! 🤖

import from byllm { Model }

# Initialize AI model
glob llm = Model(model_name="gpt-4o");

# Define AI-powered functions with just signatures!
def translate(text: str, target_language: str) -> str by llm();

def analyze_sentiment(text: str) -> str by llm(method='Reason');

with entry {
    customer_feedback = "I'm really disappointed with the product quality.";

    # AI reasons through sentiment analysis step-by-step
    sentiment = analyze_sentiment(customer_feedback);
    print(f"Customer sentiment: {sentiment}");

    # Translate the sentiment analysis to Spanish
    translated = translate(sentiment, "Spanish");
    print(f"Translated result: {translated}");
}
`,
        codeLang: "python",
        output: `
Customer sentiment: Negative. The customer expresses disappointment with product quality, which clearly indicates dissatisfaction.
Translated result: Negativo. El cliente expresa decepción con la calidad del producto, lo que indica claramente insatisfacción.
    `,
        link: "https://www.jac-lang.org/learn/jac-byllm/with_llm/"
    },
    {
        tagline: "An Agentic Programming Model",
        summary: `New programming model (object-oriented programming) to enable fast agentic-AI development`,
        filename: "agent_system.jac",
        code: `
import from byllm.llm {Model}

glob llm = Model(model_name="gemini/gemini-2.5-flash");

node Equipment {}

node Weights(Equipment) {
    has available: bool = False;

    can check with FitnessAgent entry {
        visitor.gear["weights"] = self.available;
    }
}

node Cardio(Equipment) {
    has machine: str = "treadmill";

    can check with FitnessAgent entry {
        visitor.gear["cardio"] = self.machine;
    }
}

node Trainer {
    can plan with FitnessAgent entry {
        visitor.gear["workout"] = visitor.create_workout(visitor.gear);
    }
}

walker FitnessAgent {
    has gear: dict = {};

    can start with \`root entry {
        visit [-->(\`?Equipment)];
    }

    """Create a personalized workout plan based on available equipment and space."""
    def create_workout(gear: dict) -> str by llm();
}

walker CoachWalker(FitnessAgent) {
    can get_plan with \`root entry {
        visit [-->(\`?Trainer)];
    }
}

with entry {
    root ++> Weights();
    root ++> Cardio();
    root ++> Trainer();

    agent = CoachWalker() spawn root;
    print("Your Workout Plan:");
    print(agent.gear['workout']);
}
`,
        codeLang: "python",
        output: `
**Duration:** 4 weeks
**Frequency:** 5 days a week

**Week 1-2: Building Strength and Endurance**

**Day 1: Upper Body Strength**
- Warm-up: 5 minutes treadmill walk
- Dumbbell Bench Press: 3 sets of 10-12 reps
- Dumbbell Rows: 3 sets of 10-12 reps
- Shoulder Press: 3 sets of 10-12 reps
- Bicep Curls: 3 sets of 12-15 reps
- Tricep Extensions: 3 sets of 12-15 reps
- Cool down: Stretching

**Day 2: Cardio and Core**
- Warm-up: 5 minutes treadmill walk
- Treadmill Intervals: 20 minutes (1 min sprint, 2 min walk)
- Plank: 3 sets of 30-45 seconds
- Russian Twists: 3 sets of 15-20 reps
- Bicycle Crunches: 3 sets of 15-20 reps
- Cool down: Stretching

**Day 3: Lower Body Strength**
- Warm-up: 5 minutes treadmill walk
- Squats: 3 sets of 10-12 reps
- Lunges: 3 sets of 10-12 reps per leg
- Deadlifts (dumbbells): 3 sets of 10-12 reps
- Calf Raises: 3 sets of 15-20 reps
- Glute Bridges: 3 sets of 12-15 reps
- Cool down: Stretching

**Day 4: Active Recovery**
- 30-45 minutes light treadmill walk or yoga/stretching

**Day 5: Full Body Strength**
- Warm-up: 5 minutes treadmill walk
- Circuit (repeat 3 times):
- Push-ups: 10-15 reps
- Dumbbell Squats: 10-12 reps
- Bent-over Dumbbell Rows: 10-12 reps
- Mountain Climbers: 30 seconds
- Treadmill: 15 minutes steady pace
- Cool down: Stretching

**Week 3-4: Increasing Intensity**

**Day 1: Upper Body Strength with Increased Weight**
- Follow the same structure as weeks 1-2 but increase weights by 5-10%.

**Day 2: Longer Cardio Session**
- Warm-up: 5 minutes treadmill walk
- Treadmill: 30 minutes at a steady pace
- Core Exercises: Same as weeks 1-2, but add an additional set.

**Day 3: Lower Body Strength with Increased Weight**
- Increase weights for all exercises by 5-10%.
- Add an extra set for each exercise.

**Day 4: Active Recovery**
- 30-60 minutes light treadmill walk or yoga/stretching

**Day 5: Full Body Strength Circuit with Cardio Intervals**
- Circuit (repeat 4 times):
- Push-ups: 15 reps
- Dumbbell Squats: 12-15 reps
- Jumping Jacks: 30 seconds
- Dumbbell Shoulder Press: 10-12 reps
- Treadmill: 1 minute sprint after each circuit
- Cool down: Stretching

Ensure to hydrate and listen to your body throughout the program. Adjust weights and reps as needed based on your fitness level.
    `,
        link: "https://www.jac-lang.org/learn/introduction/#beyond-oop-an-agentic-programming-model"
    },
    {
        tagline: "Object-spatial programming",
        summary: `New language constructs (node, edge and walker classes) that allow for assembling objects in a graph structure to express semantic relationships between objects, giving rise to a new paradigm for problem solving and implementation we call Object-Spatial Programming (OSP).`,
        filename: "oop_example.jac",
        code: `
# oop_calculator.jac
obj Calculator {
    has history: list[str] = [];

    def add(a: float, b: float) -> float {
        result: float = a + b;
        self.history.append(f"{a} + {b} = {result}");
        return result;
    }

    def subtract(a: float, b: float) -> float {
        result: float = a - b;
        self.history.append(f"{a} - {b} = {result}");
        return result;
    }

    def get_history() -> list[str] {
        return self.history;
    }

    def clear_history() {
        self.history = [];
    }
}

with entry {
    calc = Calculator();

    # Perform calculations
    result1: float = calc.add(5.0, 3.0);
    result2: float = calc.subtract(10.0, 4.0);

    print(f"Results: {result1}, {result2}");

    # Show history
    print("Calculation History:");
    for entry in calc.get_history() {
        print(f"  {entry}");
    }
}
`,
        codeLang: "python",
        output: `
Results: 8.0, 6.0
Calculation History:
  5.0 + 3.0 = 8.0
  10.0 - 4.0 = 6.0
    `,
        link: "#"
    },
    {
        tagline: "Zero to Infinite Scale without Code Changes",
        summary: `Jac's cloud-native abstractions make persistence and user concepts part of the language so that simple programs can run unchanged locally or in the cloud.`,
        filename: "cloud_scaling.jac",
        code: `
# Example: Run unchanged locally or in the cloud!
def scale_demo():
    print("Scaling with Jac is seamless!")
`,
        codeLang: "python",
        output: "Scaling with Jac is seamless!",
        link: "https://www.jac-lang.org/learn/jac-cloud/introduction/"
    }
];

const tabButtons = document.querySelectorAll('.vt-tab-btn');
const heading = document.getElementById('content-heading');
const codeBlock = document.getElementById('code-block');
const outputSection = document.getElementById('output-section');
const outputContent = document.getElementById('output-content');
const editorTitle = document.querySelector('.vt-editor-title');
const playToggleBtn = document.getElementById('play-toggle-btn');

let currentTabIndex = 0;
let isOutputMode = false;

function activateTab(idx) {
    currentTabIndex = idx;
    isOutputMode = false; // Reset to code view when switching tabs

    tabButtons.forEach((btn, i) => {
        btn.classList.toggle('active', i === idx);

        // Update the learn more link for the active tab
        const learnMoreLink = btn.querySelector('.vt-learn-more-link');
        if (learnMoreLink) {
            learnMoreLink.href = tabsData[i].link;
        }
    });

    heading.textContent = tabsData[idx].summary;

    // Update the editor title with the filename
    if (editorTitle) {
        editorTitle.textContent = tabsData[idx].filename;
    }

    // Reset to code view
    showCodeView();

    // Clear existing content and create code element
    codeBlock.innerHTML = '';
    const codeElement = document.createElement('code');
    codeElement.className = `language-${tabsData[idx].codeLang}`;

    // Set the text content (highlight.js will handle escaping)
    codeElement.textContent = tabsData[idx].code.trim();

    // Append to code block
    codeBlock.appendChild(codeElement);

    // Highlight the new code block
    if (window.hljs) {
        hljs.highlightElement(codeElement);
    }
}

function toggleView() {
    if (!isOutputMode) {
        showOutputView();
    } else {
        showCodeView();
    }
}

function showOutputView() {
    isOutputMode = true;
    const output = tabsData[currentTabIndex].output;
    const editor = document.querySelector('.vt-editor');

    // Format output with terminal-like appearance
    let formattedOutput = output.trim();

    // Add terminal prompt-like prefix if not already present
    if (!formattedOutput.startsWith('$') && !formattedOutput.startsWith('>')) {
        formattedOutput = formattedOutput;
    }

    // Show output content
    outputContent.textContent = formattedOutput;
    outputSection.style.display = 'block';

    // Hide code section
    codeBlock.style.display = 'none';

    // Update button with code SVG icon
    playToggleBtn.innerHTML = `
    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
      <path d="M14.6,16.6L19.2,12L14.6,7.4L13.2,8.8L16.4,12L13.2,15.2L14.6,16.6M9.4,16.6L10.8,15.2L7.6,12L10.8,8.8L9.4,7.4L4.8,12L9.4,16.6Z"/>
    </svg>
  `;
    playToggleBtn.classList.add('code-mode');
    playToggleBtn.title = 'Show Code';
}

function showCodeView() {
    isOutputMode = false;
    const editor = document.querySelector('.vt-editor');

    // Hide output section
    outputSection.style.display = 'none';

    // Show code section
    codeBlock.style.display = 'block';

    // Update button with play SVG icon
    playToggleBtn.innerHTML = `
    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
      <path d="M8 5v14l11-7z"/>
    </svg>
  `;
    playToggleBtn.classList.remove('code-mode');
    playToggleBtn.title = 'Run Code';
}

// Helper function to escape HTML entities
function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, function (m) { return map[m]; });
}

tabButtons.forEach((btn, idx) => {
    btn.addEventListener('click', (e) => {
        // Don't activate tab if clicking on the learn more link
        if (e.target.classList.contains('vt-learn-more-link')) {
            return;
        }
        activateTab(idx);
    });

    btn.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
            activateTab(idx);
        }
    });

    // Handle learn more link clicks
    const learnMoreLink = btn.querySelector('.vt-learn-more-link');
    if (learnMoreLink) {
        learnMoreLink.addEventListener('click', (e) => {
            e.stopPropagation(); // Prevent tab activation
        });
    }
});

// Add play button event listener
if (playToggleBtn) {
    playToggleBtn.addEventListener('click', toggleView);
}

// Initialize the first tab on page load
document.addEventListener('DOMContentLoaded', () => {
    activateTab(0);
});
