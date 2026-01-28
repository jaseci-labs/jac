# Pages
cl import ".global.css";

cl {
    def:pub app -> any {
        has count: int = 0;

        can with count entry {
            console.log("Count changed: ", count);
        }

        handleIncrement = lambda e: any  -> None { count = count + 1;};

        handleDecrement = lambda e: any  -> None { count = count - 1;};

        handleReset = lambda e: any  -> None { count = 0;};

        countColorClass = "text-gray-800"
        if count == 0
        else ("text-green-600" if count > 0 else "text-red-600");

        return
            <div
                className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4"
            >
                <div className="bg-white rounded-2xl shadow-2xl p-8 max-w-md w-full">
                    <h1 className="text-3xl font-bold text-gray-800 text-center mb-6">
                        Counter Application
                    </h1>
                    <div
                        className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent mb-6"
                    ></div>
                    <div className="text-center mb-8">
                        <div
                            className="text-sm font-semibold text-gray-600 mb-2 uppercase tracking-wide"
                        >
                            Current Count
                        </div>
                        <div
                            className={"text-6xl font-bold " + countColorClass + " transition-colors duration-300"}
                        >
                            {count}
                        </div>
                    </div>
                    <div
                        className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent mb-6"
                    ></div>
                    <div className="flex justify-center items-center gap-4 mb-6">
                        <button
                            className="bg-red-500 hover:bg-red-600 text-white font-bold py-3 px-6 rounded-lg shadow-lg transition-all duration-200 transform hover:scale-105 active:scale-95 text-xl"
                            onClick={handleDecrement}
                        >
                            -
                        </button>
                        <button
                            className="bg-gray-500 hover:bg-gray-600 text-white font-bold py-3 px-6 rounded-lg shadow-lg transition-all duration-200 transform hover:scale-105 active:scale-95 text-xl"
                            onClick={handleReset}
                        >
                            ↻
                        </button>
                        <button
                            className="bg-green-500 hover:bg-green-600 text-white font-bold py-3 px-6 rounded-lg shadow-lg transition-all duration-200 transform hover:scale-105 active:scale-95 text-xl"
                            onClick={handleIncrement}
                        >
                            +
                        </button>
                    </div>
                    <div className="text-center text-sm text-gray-500 italic">
                        Click the buttons to increment, decrement, or reset the counter
                    </div>
                </div>
            </div>;
    }
}
