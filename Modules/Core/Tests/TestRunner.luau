--!strict
local TestRunner = {}

local failures = 0
local total = 0

function TestRunner.runSuite(name: string, suite: { [string]: () -> () })
	print("Running Suite: " .. name)
	for testName, testFunc in pairs(suite) do
		total += 1
		local ok, err = pcall(testFunc)
		if ok then
			print("  [PASS] " .. testName)
		else
			failures += 1
			print("  [FAIL] " .. testName .. ": " .. tostring(err))
		end
	end
end

function TestRunner.assertEquals(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(string.format("Expected %s, got %s. %s", tostring(expected), tostring(actual), msg or ""), 2)
	end
end

function TestRunner.assertTrue(actual: boolean, msg: string?)
	if not actual then
		error(string.format("Expected true, got %s. %s", tostring(actual), msg or ""), 2)
	end
end

function TestRunner.assertFalse(actual: boolean, msg: string?)
	if actual then
		error(string.format("Expected false, got %s. %s", tostring(actual), msg or ""), 2)
	end
end

function TestRunner.expectError(func: () -> (), expectedMsgPattern: string?)
	local ok, err = pcall(func)
	if ok then
		error("Expected error, but function succeeded", 2)
	end
	if expectedMsgPattern and not string.find(tostring(err), expectedMsgPattern) then
		error(string.format("Expected error containing '%s', got '%s'", expectedMsgPattern, tostring(err)), 2)
	end
end

function TestRunner.getSummary()
	return {
		Total = total,
		Failures = failures,
		Passed = total - failures
	}
end

export type TestRunner = typeof(TestRunner)
return TestRunner
