/* rust-ffi teaching workspace — reusable quiz widget
   Usage in a lesson:
     <div class="quiz" data-correct="b">
       <div class="quiz-header">Check your understanding</div>
       <div class="quiz-body">
         <p class="quiz-question">The question text?</p>
         <div class="quiz-options">
           <button class="quiz-option" data-key="a">First answer</button>
           <button class="quiz-option" data-key="b">Second answer</button>
           <button class="quiz-option" data-key="c">Third answer</button>
         </div>
         <div class="quiz-feedback"></div>
       </div>
     </div>
   Set data-correct to the key of the right answer.
   Optionally add data-explain for feedback text shown on a correct guess.
*/
(function () {
  document.querySelectorAll(".quiz").forEach(function (quiz) {
    var correctKey = quiz.getAttribute("data-correct");
    var explain = quiz.getAttribute("data-explain") || "";
    var feedback = quiz.querySelector(".quiz-feedback");
    var options = quiz.querySelectorAll(".quiz-option");

    options.forEach(function (opt) {
      opt.addEventListener("click", function () {
        var key = opt.getAttribute("data-key");
        options.forEach(function (o) {
          o.classList.remove("correct", "wrong");
          o.disabled = true;
        });
        if (key === correctKey) {
          opt.classList.add("correct");
          feedback.className = "quiz-feedback show ok";
          feedback.textContent = "Correct." + (explain ? " " + explain : "");
        } else {
          opt.classList.add("wrong");
          var correctOpt = quiz.querySelector(
            '.quiz-option[data-key="' + correctKey + '"]'
          );
          if (correctOpt) correctOpt.classList.add("correct");
          feedback.className = "quiz-feedback show no";
          feedback.textContent = "Not quite — the highlighted answer is correct." +
            (explain ? " " + explain : "");
        }
      });
    });
  });
})();
