	Lib.ContextMenu = (function()
		local funcs = {}
		local mouse

		local function createGui(self)
			local contextGui = create({
				{1,"ScreenGui",{DisplayOrder=1000000,Name="Context",ZIndexBehavior=1,}},
				{2,"Frame",{Active=true,BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),Name="Main",Parent={1},Position=UDim2.new(0.5,-100,0.5,-150),Size=UDim2.new(0,200,0,100),}},
				{3,"UICorner",{CornerRadius=UDim.new(0,4),Parent={2},}},
				{4,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),Name="Container",Parent={2},Position=UDim2.new(0,1,0,1),Size=UDim2.new(1,-2,1,-2),}},
				{5,"UICorner",{CornerRadius=UDim.new(0,4),Parent={4},}},
				{6,"ScrollingFrame",{Active=true,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),Name="List",Parent={4},Position=UDim2.new(0,2,0,2),ScrollBarImageColor3=Color3.new(0,0,0),ScrollBarThickness=4,Size=UDim2.new(1,-4,1,-4),VerticalScrollBarInset=1,}},
				{7,"UIListLayout",{Parent={6},SortOrder=2,}},
				{8,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="SearchFrame",Parent={4},Size=UDim2.new(1,0,0,24),Visible=false,}},
				{9,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.1176470592618,0.1176470592618,0.1176470592618),BorderSizePixel=0,Name="SearchContainer",Parent={8},Position=UDim2.new(0,3,0,3),Size=UDim2.new(1,-6,0,18),}},
				{10,"TextBox",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="SearchBox",Parent={9},PlaceholderColor3=Color3.new(0.39215689897537,0.39215689897537,0.39215689897537),PlaceholderText="Search",Position=UDim2.new(0,4,0,0),Size=UDim2.new(1,-8,0,18),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,}},
				{11,"UICorner",{CornerRadius=UDim.new(0,2),Parent={9},}},
				{12,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="Line",Parent={8},Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,1),}},
				{13,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BackgroundTransparency=1,BorderColor3=Color3.new(0.33725491166115,0.49019610881805,0.73725491762161),BorderSizePixel=0,Font=3,Name="Entry",Parent={1},Size=UDim2.new(1,0,0,22),Text="",TextSize=14,Visible=false,}},
				{14,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="EntryName",Parent={13},Position=UDim2.new(0,24,0,0),Size=UDim2.new(1,-24,1,0),Text="Duplicate",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
				{15,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Shortcut",Parent={13},Position=UDim2.new(0,24,0,0),Size=UDim2.new(1,-30,1,0),Text="Ctrl+D",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
				{16,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ImageRectOffset=Vector2.new(304,0),ImageRectSize=Vector2.new(16,16),Name="Icon",Parent={13},Position=UDim2.new(0,2,0,3),ScaleType=4,Size=UDim2.new(0,16,0,16),}},
				{17,"UICorner",{CornerRadius=UDim.new(0,4),Parent={13},}},
				{18,"Frame",{BackgroundColor3=Color3.new(0.21568629145622,0.21568629145622,0.21568629145622),BackgroundTransparency=1,BorderSizePixel=0,Name="Divider",Parent={1},Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,0,7),Visible=false,}},
				{19,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="Line",Parent={18},Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(1,0,0,1),}},
				{20,"TextLabel",{AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="DividerName",Parent={18},Position=UDim2.new(0,2,0.5,0),Size=UDim2.new(1,-4,1,0),Text="Objects",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=0.60000002384186,TextXAlignment=0,Visible=false,}}
			})

			self.GuiElems.Main = contextGui.Main
			self.GuiElems.List = contextGui.Main.Container.List
			self.GuiElems.Entry = contextGui.Entry
			self.GuiElems.Divider = contextGui.Divider
			self.GuiElems.SearchFrame = contextGui.Main.Container.SearchFrame
			self.GuiElems.SearchBar = self.GuiElems.SearchFrame.SearchContainer.SearchBox
			Lib.ViewportTextBox.convert(self.GuiElems.SearchBar)

			self.GuiElems.SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
				local lower,find = string.lower,string.find
				local searchText = lower(self.GuiElems.SearchBar.Text)
				local items = self.Items
				local map = self.ItemToEntryMap

				if searchText ~= "" then
					local results = {}
					local count = 1
					for i = 1,#items do
						local item = items[i]
						local entry = map[item]
						if entry then
							if not item.Divider and find(lower(item.Name),searchText,1,true) then
								results[count] = item
								count = count + 1
							else
								entry.Visible = false
							end
						end
					end
					table.sort(results,function(a,b) return a.Name < b.Name end)
					for i = 1,#results do
						local entry = map[results[i]]
						entry.LayoutOrder = i
						entry.Visible = true
					end
				else
					for i = 1,#items do
						local entry = map[items[i]]
						if entry then entry.LayoutOrder = i entry.Visible = true end
					end
				end

				local toSize = self.GuiElems.List.UIListLayout.AbsoluteContentSize.Y + 6
				self.GuiElems.List.CanvasSize = UDim2.new(0,0,0,toSize-6)
			end)

			return contextGui
		end

		funcs.Add = function(self,item)
			local newItem = {
				Name = item.Name or "Item",
				Icon = item.Icon or "",
				Shortcut = item.Shortcut or "",
				OnClick = item.OnClick,
				OnHover = item.OnHover,
				Disabled = item.Disabled or false,
				DisabledIcon = item.DisabledIcon or "",
				IconMap = item.IconMap,
				OnRightClick = item.OnRightClick
			}
			
			newItem.DisabledIcon = newItem.Icon

			if self.QueuedDivider then
				local text = self.QueuedDividerText and #self.QueuedDividerText > 0 and self.QueuedDividerText
				self:AddDivider(text)
			end
			self.Items[#self.Items+1] = newItem
			self.Updated = nil
		end

		funcs.AddRegistered = function(self,name,disabled)
			if not self.Registered[name] then error(name.." is not registered") end

			if self.QueuedDivider then
				local text = self.QueuedDividerText and #self.QueuedDividerText > 0 and self.QueuedDividerText
				self:AddDivider(text)
			end
			local original = self.Registered[name]
			local item = {
				Name = original.Name,
				Icon = original.Icon,
				Shortcut = original.Shortcut,
				OnClick = original.OnClick,
				OnHover = original.OnHover,
				Disabled = (disabled ~= nil) and disabled or original.Disabled,
				DisabledIcon = original.DisabledIcon,
				IconMap = original.IconMap,
				OnRightClick = original.OnRightClick,
				NoHide = original.NoHide
			}
			self.Items[#self.Items+1] = item
			self.Updated = nil
		end

		funcs.Register = function(self,name,item)
			self.Registered[name] = {
				Name = item.Name or "Item",
				Icon = item.Icon or "",
				Shortcut = item.Shortcut or "",
				OnClick = item.OnClick,
				OnHover = item.OnHover,
				DisabledIcon = item.DisabledIcon or "",
				IconMap = item.IconMap,
				OnRightClick = item.OnRightClick
			}
		end

		funcs.UnRegister = function(self,name)
			self.Registered[name] = nil
		end

		funcs.AddDivider = function(self,text)
			self.QueuedDivider = false
			local textWidth = text and service.TextService:GetTextSize(text,14,Enum.Font.SourceSans,Vector2.new(999999999,20)).X or nil
			table.insert(self.Items,{Divider = true, Text = text, TextSize = textWidth and textWidth+4})
			self.Updated = nil
		end

		funcs.QueueDivider = function(self,text)
			self.QueuedDivider = true
			self.QueuedDividerText = text or ""
		end

		funcs.Clear = function(self)
			self.Items = {}
			self.Updated = nil
		end

		funcs.Refresh = function(self)
			for i,v in pairs(self.GuiElems.List:GetChildren()) do
				if not v:IsA("UIListLayout") then
					v:Destroy()
				end
			end
			local map = {}
			self.ItemToEntryMap = map

			local dividerFrame = self.GuiElems.Divider
			local contextList = self.GuiElems.List
			local entryFrame = self.GuiElems.Entry
			local items = self.Items

			for i = 1,#items do
				local item = items[i]
				if item.Divider then
					local newDivider = dividerFrame:Clone()
					newDivider.Line.BackgroundColor3 = self.Theme.DividerColor
					if item.Text then
						newDivider.Size = UDim2.new(1,0,0,20)
						newDivider.Line.Position = UDim2.new(0,item.TextSize,0.5,0)
						newDivider.Line.Size = UDim2.new(1,-item.TextSize,0,1)
						newDivider.DividerName.TextColor3 = self.Theme.TextColor
						newDivider.DividerName.Text = item.Text
						newDivider.DividerName.Visible = true
					end
					newDivider.Visible = true
					map[item] = newDivider
					newDivider.Parent = contextList
				else
					local newEntry = entryFrame:Clone()
					newEntry.BackgroundColor3 = self.Theme.HighlightColor
					newEntry.EntryName.TextColor3 = self.Theme.TextColor
					newEntry.EntryName.Text = item.Name
					newEntry.Shortcut.Text = item.Shortcut
					if item.Disabled then
						newEntry.EntryName.TextColor3 = Color3.new(150/255,150/255,150/255)
						newEntry.Shortcut.TextColor3 = Color3.new(150/255,150/255,150/255)
					end

					if self.Iconless then
						newEntry.EntryName.Position = UDim2.new(0,2,0,0)
						newEntry.EntryName.Size = UDim2.new(1,-4,0,20)
						newEntry.Icon.Visible = false
					else			
						local iconIndex
						if item.Disabled and item.DisabledIcon then
							iconIndex = item.DisabledIcon
						elseif item.Icon then
							iconIndex =  item.Icon
						end
						
						-- Explorer.MiscIcons:DisplayExplorerIcons(newEntry.Icon, iconIndex)
						if item.IconMap then
							if type(iconIndex) == "number" then
								item.IconMap:Display(newEntry.Icon, iconIndex)
							elseif type(iconIndex) == "string" then
								item.IconMap:DisplayByKey(newEntry.Icon, iconIndex)
							end
						elseif type(iconIndex) == "string" then
							newEntry.Icon.Image = iconIndex
						end
					end

					if not item.Disabled then
						if item.OnClick then
							newEntry.MouseButton1Click:Connect(function()
								item.OnClick(item.Name)
								if not item.NoHide then
									self:Hide()
								end
							end)
						end
						if item.OnRightClick then
							local clicked = false
							local function trigger()
								if clicked then return end
								clicked = true
								task.spawn(function()
									item.OnRightClick(item.Name)
									if not item.NoHide then
										self:Hide()
									end
									task.wait(0.1)
									clicked = false
								end)
							end
							newEntry.MouseButton2Down:Connect(trigger)
							newEntry.MouseButton2Click:Connect(trigger)
						end
					end

					newEntry.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							newEntry.BackgroundTransparency = 0
						end
					end)

					newEntry.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							newEntry.BackgroundTransparency = 1
						end
					end)

					newEntry.Visible = true
					map[item] = newEntry
					newEntry.Parent = contextList
				end
			end
			self.Updated = true
		end

		funcs.Show = function(self,x,y)
			self:Hide(true)

			local elems = self.GuiElems
			elems.SearchFrame.Visible = self.SearchEnabled
			elems.List.Position = UDim2.new(0,2,0,2 + (self.SearchEnabled and 24 or 0))
			elems.List.Size = UDim2.new(1,-4,1,-4 - (self.SearchEnabled and 24 or 0))
			if self.SearchEnabled and self.ClearSearchOnShow then elems.SearchBar.Text = "" end
			self.GuiElems.List.CanvasPosition = Vector2.new(0,0)

			if not self.Updated then
				self:Refresh()
			end

			-- Vars
			local reverseY = false
			local x,y = x or mouse.X, y or mouse.Y
			local maxX,maxY = mouse.ViewSizeX,mouse.ViewSizeY

			-- Position and show
			if x + self.Width > maxX then
				x = self.ReverseX and x - self.Width or maxX - self.Width
			end
			elems.Main.Position = UDim2.new(0,x,0,y)
			elems.Main.Size = UDim2.new(0,self.Width,0,0)
			self.Gui.DisplayOrder = Main.DisplayOrders.Menu
			Lib.ShowGui(self.Gui)

			-- Size adjustment
			local toSize = elems.List.UIListLayout.AbsoluteContentSize.Y + 6 -- Padding
			if self.MaxHeight and toSize > self.MaxHeight then
				elems.List.CanvasSize = UDim2.new(0,0,0,toSize-6)
				toSize = self.MaxHeight
			else
				elems.List.CanvasSize = UDim2.new(0,0,0,0)
			end
			if y + toSize > maxY then reverseY = true end

			-- Close event
			local closable
			if self.CloseEvent then self.CloseEvent:Disconnect() end
			self.CloseEvent = service.UserInputService.InputBegan:Connect(function(input)
				if not closable then return end

				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if not Lib.CheckMouseInGui(elems.Main) then
						self.CloseEvent:Disconnect()
						self:Hide()
					end
				end
			end)

			-- Resize
			if reverseY then
				elems.Main.Position = UDim2.new(0,x,0,y-(self.ReverseYOffset or 0))
				local newY = y - toSize - (self.ReverseYOffset or 0)
				y = newY >= 0 and newY or 0
				elems.Main:TweenSizeAndPosition(UDim2.new(0,self.Width,0,toSize),UDim2.new(0,x,0,y),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.2,true)
			else
				elems.Main:TweenSize(UDim2.new(0,self.Width,0,toSize),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.2,true)
			end

			-- Close debounce
			Lib.FastWait()
			if self.SearchEnabled and self.FocusSearchOnShow then elems.SearchBar:CaptureFocus() end
			closable = true
		end

		local active3DPanels = {}

		Lib.ClearAll3DPanels = function()
			for i = #active3DPanels, 1, -1 do
				local panel = table.remove(active3DPanels, i)
				if panel then
					panel:Hide(true)
				end
			end
		end

		Lib.GetActive3DPanels = function()
			return active3DPanels
		end

		funcs.Hide = function(self, immediate)
			if self.RenderConnection then
				self.RenderConnection:Disconnect()
				self.RenderConnection = nil
			end
			if self.CloseEvent then
				self.CloseEvent:Disconnect()
				self.CloseEvent = nil
			end
			local uiScale = self.GuiElems.Main:FindFirstChildOfClass("UIScale")

			-- Get back face scale if it exists
			local backScale
			if self.BillboardGuiBack then
				local backFrame = self.BillboardGuiBack:FindFirstChildOfClass("Frame")
				backScale = backFrame and backFrame:FindFirstChildOfClass("UIScale")
			end

			local function cleanup()
				if uiScale then
					uiScale:Destroy()
				end
				
				-- Critical: Reparent elems.Main to self.Gui BEFORE destroying BillboardGui/BillboardAdornee.
				-- If BillboardGui is destroyed first, Roblox recursively destroys elems.Main, locking its Parent property.
				self.GuiElems.Main.Parent = self.Gui

				if self.BillboardGui then
					self.BillboardGui:Destroy()
					self.BillboardGui = nil
				end
				if self.BillboardGuiBack then
					self.BillboardGuiBack:Destroy()
					self.BillboardGuiBack = nil
				end
				if self.BillboardAdornee then
					self.BillboardAdornee:Destroy()
					self.BillboardAdornee = nil
				end
				self.TargetInstance = nil
				self.Gui.Parent = nil
				self.Hiding = nil

				-- Remove from active3DPanels
				for i = #active3DPanels, 1, -1 do
					if active3DPanels[i] == self then
						table.remove(active3DPanels, i)
					end
				end
			end

			if immediate or not uiScale or not self.BillboardGui then
				cleanup()
			else
				self.Hiding = true
				-- Play closing scale-down animation in unison for both front and back
				local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				local tween = service.TweenService:Create(uiScale, tweenInfo, {Scale = 0.01})
				
				if backScale then
					local backTween = service.TweenService:Create(backScale, tweenInfo, {Scale = 0.01})
					backTween:Play()
				end

				local conn
				conn = tween.Completed:Connect(function()
					conn:Disconnect()
					if self.Hiding then
						cleanup()
					end
				end)
				tween:Play()
			end
		end

		funcs.Show3D = function(self, targetInstance, hitPosition)
			self:Hide(true)

			local elems = self.GuiElems
			elems.SearchFrame.Visible = self.SearchEnabled
			elems.List.Position = UDim2.new(0,2,0,2 + (self.SearchEnabled and 24 or 0))
			elems.List.Size = UDim2.new(1,-4,1,-4 - (self.SearchEnabled and 24 or 0))
			if self.SearchEnabled and self.ClearSearchOnShow then elems.SearchBar.Text = "" end
			self.GuiElems.List.CanvasPosition = Vector2.new(0,0)

			if not self.Updated then
				self:Refresh()
			end

			if not targetInstance or not targetInstance:IsA("BasePart") then
				self:Show()
				return
			end

			local toSize = elems.List.UIListLayout.AbsoluteContentSize.Y + 6
			if self.MaxHeight and toSize > self.MaxHeight then
				elems.List.CanvasSize = UDim2.new(0,0,0,toSize-6)
				toSize = self.MaxHeight
			else
				elems.List.CanvasSize = UDim2.new(0,0,0,0)
			end

			local camera = workspace.CurrentCamera
			local cameraPos = camera.CFrame.Position

			-- Calculate 3D physical size for true perspective (maintaining 1:1 aspect ratio)
			local partWidth = 7
			local partHeight = partWidth * (toSize / self.Width)

			-- Visibility and obstruction check logic
			local toCamera = (cameraPos - hitPosition).Magnitude > 0.001 and (cameraPos - hitPosition).Unit or Vector3.new(0, 1, 0)
			local basePos = hitPosition + toCamera * 1.5

			-- Helper to raycast ignoring triggers/invisible parts/character
			local function isObscured(startPos, endPos)
				local filter = {service.Players.LocalPlayer.Character}
				for _, panel in ipairs(active3DPanels) do
					if panel.BillboardAdornee then
						table.insert(filter, panel.BillboardAdornee)
					end
				end

				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				
				while true do
					params.FilterDescendantsInstances = filter
					local result = workspace:Raycast(startPos, endPos - startPos, params)
					if not result then
						return nil
					end
					
					local hitPart = result.Instance
					local isVisualObstacle = hitPart.Transparency < 0.95
					if isVisualObstacle then
						return result
					else
						table.insert(filter, hitPart)
					end
				end
			end

			-- Calculate base orientation CFrame
			local lookTarget = Vector3.new(cameraPos.X, basePos.Y, cameraPos.Z)
			local baseCFrame
			if (lookTarget - basePos).Magnitude > 0.01 then
				baseCFrame = CFrame.lookAt(basePos, lookTarget)
			else
				baseCFrame = CFrame.lookAt(basePos, cameraPos)
			end

			-- Test center and 4 corners of the UI plane
			local halfW = partWidth / 2
			local halfH = partHeight / 2
			local testOffsets = {
				Vector3.new(0, 0, 0), -- Center
				Vector3.new(-halfW, halfH, 0), -- Top-Left
				Vector3.new(halfW, halfH, 0), -- Top-Right
				Vector3.new(-halfW, -halfH, 0), -- Bottom-Left
				Vector3.new(halfW, -halfH, 0) -- Bottom-Right
			}

			local maxAdjustment = 0
			for _, offset in ipairs(testOffsets) do
				local P = baseCFrame:PointToWorldSpace(offset)
				local result = isObscured(cameraPos, P)
				if result then
					local distToObstruction = (result.Position - cameraPos).Magnitude
					local distToPoint = (P - cameraPos).Magnitude
					if distToObstruction < distToPoint - 0.1 then
						local needed = (distToPoint - distToObstruction) + 0.5 -- 0.5 studs padding
						if needed > maxAdjustment then
							maxAdjustment = needed
						end
					end
				end
			end

			-- Apply the adjustment to position the UI in front of all obstructions
			local finalPos = basePos
			if maxAdjustment > 0 then
				local maxSafeDistance = (cameraPos - basePos).Magnitude - 3.0
				local adjustment = math.min(maxAdjustment, math.max(0, maxSafeDistance))
				finalPos = basePos + toCamera * adjustment
			end

			-- Create static anchored invisible part at finalPos
			local spatialPart = Instance.new("Part")
			spatialPart.Name = "_DPP_SpatialPart"
			spatialPart.Size = Vector3.new(partWidth, partHeight, 0.2)
			
			-- Orient to face the camera position (locking pitch rotation creates a cleaner spatial UI)
			local lookTargetFinal = Vector3.new(cameraPos.X, finalPos.Y, cameraPos.Z)
			if (lookTargetFinal - finalPos).Magnitude > 0.01 then
				spatialPart.CFrame = CFrame.lookAt(finalPos, lookTargetFinal)
			else
				spatialPart.CFrame = CFrame.lookAt(finalPos, cameraPos)
			end

			spatialPart.Transparency = 1
			spatialPart.CanCollide = false
			spatialPart.CanTouch = false
			spatialPart.CanQuery = true
			spatialPart.Anchored = true
			spatialPart.Parent = workspace
			self.BillboardAdornee = spatialPart
			self.TargetInstance = targetInstance

			-- SurfaceGui for Front Face (Interactive menu)
			local surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Adornee = spatialPart
			surfaceGui.Face = Enum.NormalId.Front
			surfaceGui.AlwaysOnTop = false
			surfaceGui.LightInfluence = 0
			surfaceGui.ClipsDescendants = false
			surfaceGui.CanvasSize = Vector2.new(self.Width, toSize)
			surfaceGui.Name = "_DPP_SurfaceGui"
			surfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

			elems.Main.Parent = surfaceGui
			elems.Main.ClipsDescendants = false
			elems.Main.Size = UDim2.new(1, 0, 1, 0)
			elems.Main.Position = UDim2.new(0, 0, 0, 0)

			local uiScale = elems.Main:FindFirstChildOfClass("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Parent = elems.Main
			end
			uiScale.Scale = 0.01

			self.BillboardGui = surfaceGui
			Lib.ShowGui(surfaceGui)

			-- SurfaceGui for Back Face (Sleek Glass Backing)
			local backGui = Instance.new("SurfaceGui")
			backGui.Adornee = spatialPart
			backGui.Face = Enum.NormalId.Back
			backGui.AlwaysOnTop = false
			backGui.LightInfluence = 0
			backGui.ClipsDescendants = false
			backGui.CanvasSize = Vector2.new(self.Width, toSize)
			backGui.Name = "_DPP_BackGui"
			backGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

			local backFrame = Instance.new("Frame")
			backFrame.Size = UDim2.new(1, 0, 1, 0)
			backFrame.BackgroundColor3 = elems.Main.BackgroundColor3 or Color3.fromRGB(30, 30, 30)
			backFrame.BackgroundTransparency = 0.45
			backFrame.BorderSizePixel = 0
			backFrame.Parent = backGui

			local backCorner = Instance.new("UICorner")
			backCorner.CornerRadius = UDim.new(0, 8)
			backCorner.Parent = backFrame

			local backStroke = Instance.new("UIStroke")
			backStroke.Color = Color3.fromRGB(80, 80, 80)
			backStroke.Thickness = 1.5
			backStroke.Transparency = 0.5
			backStroke.Parent = backFrame

			local backLabel = Instance.new("TextLabel")
			backLabel.Size = UDim2.new(1, 0, 1, 0)
			backLabel.BackgroundTransparency = 1
			backLabel.Text = "DEX++"
			backLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			backLabel.TextTransparency = 0.6
			backLabel.TextSize = 24
			backLabel.Font = Enum.Font.GothamBold
			backLabel.Parent = backFrame

			local backScale = Instance.new("UIScale")
			backScale.Parent = backFrame
			backScale.Scale = 0.01

			self.BillboardGuiBack = backGui
			Lib.ShowGui(backGui)

			-- Enforce maximum panel limit (FIFO)
			if not table.find(active3DPanels, self) then
				table.insert(active3DPanels, self)
			end
			local maxPanels = Settings.Explorer.ViewportContextMenuMaxPanels or 10
			if maxPanels > 0 then
				while #active3DPanels > maxPanels do
					local oldest = table.remove(active3DPanels, 1)
					if oldest then
						oldest:Hide(true)
					end
				end
			end

			-- Opening Animation (Scale up smoothly in unison with a subtle bounce)
			local openTween = service.TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.0})
			openTween:Play()

			local backOpenTween = service.TweenService:Create(backScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.0})
			backOpenTween:Play()

			local closable = false
			if self.CloseEvent then self.CloseEvent:Disconnect() end
			self.CloseEvent = service.UserInputService.InputBegan:Connect(function(input)
				if not closable then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local overDex = false
					local isOverDexGui = (Explorer and Explorer.isOverDexGui) or (Apps and Apps.Explorer and Apps.Explorer.isOverDexGui)
					if isOverDexGui and isOverDexGui() then
						overDex = true
					else
						for _, panel in ipairs(active3DPanels) do
							if panel.GuiElems and panel.GuiElems.Main then
								if Lib.CheckMouseInGui(panel.GuiElems.Main) then
									overDex = true
									break
								end
							end
						end
					end

					if not overDex then
						self:Hide()
					end
				end
			end)

			local outsideSince = nil
			self.RenderConnection = service.RunService.RenderStepped:Connect(function()
				if not spatialPart or not spatialPart.Parent then
					self:Hide(true)
					return
				end

				-- Check distance using the CAMERA position instead of Character
				local refCamera = workspace.CurrentCamera
				local referencePos = refCamera.CFrame.Position
				local distance = (spatialPart.Position - referencePos).Magnitude

				-- Check max distance limit
				local maxDistance = Settings.Explorer.ViewportContextMenuMaxDistance or 50
				local isOutside = false
				if maxDistance > 0 and distance > maxDistance then
					isOutside = true
				end

				if isOutside then
					local closeDelay = Settings.Explorer.ViewportContextMenuDistanceCloseTime or 10
					if closeDelay == 0 then
						outsideSince = nil -- Reset if configured to stay open permanently
					else
						if not outsideSince then
							outsideSince = os.clock()
						else
							local elapsed = os.clock() - outsideSince
							if elapsed >= closeDelay then
								self:Hide()
								return
							end
						end
					end
				else
					outsideSince = nil -- Returned within boundaries: cancel countdown timer
				end
			end)

			Lib.FastWait()
			closable = true
		end

		funcs.ApplyTheme = function(self,data)
			local theme = self.Theme
			theme.ContentColor = data.ContentColor or Settings.Theme.Menu
			theme.OutlineColor = data.OutlineColor or Settings.Theme.Menu
			theme.DividerColor = data.DividerColor or Settings.Theme.Outline2
			theme.TextColor = data.TextColor or Settings.Theme.Text
			theme.HighlightColor = data.HighlightColor or Settings.Theme.Main1

			self.GuiElems.Main.BackgroundColor3 = theme.OutlineColor
			self.GuiElems.Main.Container.BackgroundColor3 = theme.ContentColor
		end

		local mt = {__index = funcs}
		local function new()
			if not mouse then mouse = Main.Mouse or service.Players.LocalPlayer:GetMouse() end

			local obj = setmetatable({
				Width = 200,
				MaxHeight = nil,
				Iconless = false,
				SearchEnabled = false,
				ClearSearchOnShow = true,
				FocusSearchOnShow = true,
				Updated = false,
				QueuedDivider = false,
				QueuedDividerText = "",
				Items = {},
				Registered = {},
				GuiElems = {},
				Theme = {}
			},mt)
			obj.Gui = createGui(obj)
			obj:ApplyTheme({})
			return obj
		end

		return {new = new}
	end)()
