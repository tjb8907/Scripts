AICombine2 = {};	
source("dataS/scripts/vehicles/specializations/AICombineSetStartedEvent.lua");	
source("dataS/scripts/vehicles/specializations/AISetImplementsMoveDownEvent.lua");	
	
function AICombine2.prerequisitesPresent(specializations)	
	return SpecializationUtil.hasSpecialization(Hirable2, specializations) and SpecializationUtil.hasSpecialization(Combine, specializations);
end;	
	
function AICombine2:load(xmlFile)	
	self.startAIThreshing = SpecializationUtil.callSpecializationsFunction("startAIThreshing");
	self.stopAIThreshing = SpecializationUtil.callSpecializationsFunction("stopAIThreshing");
	self.setAIImplementsMoveDown = SpecializationUtil.callSpecializationsFunction("setAIImplementsMoveDown");
	self.onTrafficCollisionTrigger = AICombine2.onTrafficCollisionTrigger;	
	self.canStartAIThreshing = AICombine2.canStartAIThreshing;	
	self.getIsAIThreshingAllowed = AICombine2.getIsAIThreshingAllowed;	
	
	self.isAIThreshing = false;	
	self.aiTreshingDirectionNode = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTreshingDirectionNode#index"));
	if self.aiTreshingDirectionNode == nil then	
		self.aiTreshingDirectionNode = self.components[1].node;	
	end;	
	
	self.lookAheadDistance = 10;	
	self.turnTimeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnTimeout"),200);
	self.turnTimeoutLong = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnTimeoutLong"), 6000);
	self.turnTimer = self.turnTimeout;	
	self.turnEndDistance = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnEndDistance"), 4);
		
	self.waitForTurnTimeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.waitForTurnTime"), 1500);
	self.waitForTurnTime = 0;	
		
		
	self.sideWatchDirOffset = -8;	
	self.sideWatchDirSize = 8;	
		
	self.frontAreaSize = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.frontAreaSize#value"), 2);
		
	self.waitingForTrailerToUnload = false;	
	
	self.waitingForDischarge = false;	
	self.waitForDischargeTime = 0;	
	self.waitForDischargeTimeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.waitForDischargeTime"), 10000);
		
	self.turnStage = 0;	
	
	
	self.aiLeftMarker = Utils.indexToObject(self.components, getXMLString(xmlFile,"vehicle.aiLeftMarker#index"));
	self.aiRightMarker = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiRightMarker#index"));
	self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	
	self.aiTurnThreshWidthScale = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.aiTurnThreshWidthScale#value"), 0.9);
	self.aiTurnThreshWidthMaxDifference = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.aiTurnThreshWidthMaxDifference#value"), 0.6); -- do at most a 0.6m overlap
	
	
	self.trafficCollisionIgnoreList = {};	
	for k,v in pairs(self.components) do	
	self.trafficCollisionIgnoreList[v.node] = true;	
	end;	
	self.numCollidingVehicles = {};	
	
	self.driveBackTimeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.driveBackTimeout"), 1000);
	self.driveBackTime = 0;	
	self.driveBackAfterDischarge = false;	
	
	self.dtSum = 0;	
	
	self.turnStage1Timeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnForwardTimeout"), 20000);
	self.turnStage1AngleCosThreshold = math.cos(math.rad(Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnForwardAngleThreshold"), 75)));
	self.turnStage2Timeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnBackwardTimeout"), 20000);
	self.turnStage2AngleCosThreshold = math.cos(math.rad(Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.turnBackwardAngleThreshold"), 30)));
	self.turnStage4Timeout = 3000;	
	
	self.waitingForWeather = false;	
	
	self.aiRescueTimeout = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.aiRescue#timeout"), 10000);
	self.aiRescueTimer = self.aiRescueTimeout;	
	self.aiRescueForce = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.aiRescue#force"), 60);
	self.aiRescueSpeedThreshold = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.aiRescue#speedThreshold"), 0.0001);
	self.aiRescueNode = Utils.indexToObject(self.components, getXMLString(xmlFile,"vehicle.aiRescue#index"));
	if self.aiRescueNode == nil then	
		self.aiRescueNode = self.components[1].node;	
	end;	
	
	self.numAttachedTrailers = 0;	
	
	--self.debugDirection = loadI3DFile("data/debugDirection.i3d");	
	--link(self.aiTreshingDirectionNode, self.debugDirection);	
		
	--self.debugPosition = loadI3DFile("data/debugPosition.i3d");	
	--link(self.aiTreshingDirectionNode, self.debugPosition);	
	
end;	
	
function AICombine2:delete()	
	--self:stopAIThreshing();	
	
	AICombine2.removeCollisionTrigger(self, self);	
	for _,implement in pairs(self.attachedImplements) do	
		if implement.object ~= nil then	
			AICombine2.removeCollisionTrigger(self, implement.object);	
		end	
	end;	
end;	
	
function AICombine2:readStream(streamId, connection)	
	local isAIThreshing = streamReadBool(streamId);	
	if isAIThreshing then	
		self:startAIThreshing(true);	
	else	
		self:stopAIThreshing(true);	
	end;	
end;	
	
function AICombine2:writeStream(streamId, connection)	
	streamWriteBool(streamId, self.isAIThreshing);	
end;	
	
function AICombine2:mouseEvent(posX, posY, isDown, isUp, button)	
end;	
	
function AICombine2:keyEvent(unicode, sym, modifier, isDown)	
end;	
	
function AICombine2:update(dt)	
	if self:getIsActiveForInput(false) then	
		if InputBinding.hasEvent(InputBinding.TOGGLE_AI) then	
			if g_currentMission:getHasPermission("hireAI") then	
				if self.isAIThreshing then	
					self:stopAIThreshing();	
				else	
					if self:canStartAIThreshing() then	
						self:startAIThreshing();	
					end;	
				end;	
			end;	
		end;	
	end;	
end;	
	
function AICombine2:updateTick(dt)	
	if self.isServer then	
		if self.isAIThreshing then	
			if self.isBroken then	
				self:stopAIThreshing();	
			end;	
	
			self.dtSum = self.dtSum + dt;	
			if self.dtSum > 50 then	
				AICombine2.updateAIMovement(self, self.dtSum);	
				self.dtSum = 0;	
			end;	
	
			if self.isAIThreshing then	
				if (self.grainTankFillLevel > 0 or self.grainTankCapacity <= 0) and (self.grainTankFillLevel >= self.grainTankCapacity*0.8 or next(self.combineTrailersInRange) ~= nil) then
					local pipeState = self:getCombineTrailerInRangePipeState();	
					if pipeState > 0 then	
						self:setPipeState(pipeState);	
					else	
						self:setPipeState(2);	
					end;	
					if next(self.combineTrailersInRange) ~= nil then	
						self.waitForDischargeTime = self.time + self.waitForDischargeTimeout;
					end;	
					if self.grainTankFillLevel >= self.grainTankCapacity and self.grainTankCapacity > 0 then
						self.driveBackAfterDischarge = true;	
						self.waitingForDischarge = true;	
						self.waitForDischargeTime = self.time + self.waitForDischargeTimeout;
					end;	
				else	
					--no trailer in range and not full	
					if (self.waitingForDischarge and self.grainTankFillLevel <= 0)or self.waitForDischargeTime <= self.time then
						self.waitingForDischarge = false;	
						if self.driveBackAfterDischarge then	
							self.driveBackTime = self.time + self.driveBackTimeout;
							self.driveBackAfterDischarge = false;	
						end;	
						if next(self.combineTrailersInRange) == nil then	
							-- only close the pipe if no trailer is in range	
							self:setPipeState(1);	
						end;	
						if self:getIsThreshingAllowed(true) then	
							self:setIsThreshing(true);	
						end;	
					end;	
				end;	
			end	
		else	
			self.dtSum = 0;	
		end;	
	end;	
end;	
	
function AICombine2:draw()	
	if g_currentMission:getHasPermission("hireAI") then	
		if self.isAIThreshing then	
			g_currentMission:addHelpButtonText(g_i18n:getText("DismissEmployee"),InputBinding.TOGGLE_AI);
		else	
			if self:canStartAIThreshing() then	
				g_currentMission:addHelpButtonText(g_i18n:getText("HireEmployee"),InputBinding.TOGGLE_AI);
			end;	
		end;	
	end	
end;	
	
function AICombine2:startAIThreshing(noEventSend)	
	if noEventSend == nil or noEventSend == false then	
		if g_server ~= nil then	
			g_server:broadcastEvent(AICombineSetStartedEvent:new(self, true), nil,nil, self);
		else	
			g_client:getServerConnection():sendEvent(AICombineSetStartedEvent:new(self, true));
		end;	
	end;	
	self:hire();	
	if not self.isAIThreshing then	
		self.isAIThreshing = true;	
		if self.isServer then	
			self.turnTimer = self.turnTimeoutLong;	
			self.turnStage = 0;	
			local dx,_,dz = localDirectionToWorld(self.aiTreshingDirectionNode, 0,0, 1);
			if g_currentMission.snapAIDirection then	
				local snapAngle = self:getDirectionSnapAngle();	
				snapAngle = math.max(snapAngle, math.pi/(g_currentMission.terrainDetailAngleMaxValue+1));
				local angleRad = Utils.getYRotationFromDirection(dx, dz)	
				angleRad = math.floor(angleRad / snapAngle + 0.5) * snapAngle;	
				self.aiThreshingDirectionX, self.aiThreshingDirectionZ = Utils.getDirectionFromYRotation(angleRad);
			else	
				local length = Utils.vector2Length(dx,dz);	
				self.aiThreshingDirectionX = dx/length;	
				self.aiThreshingDirectionZ = dz/length;	
			end;	
			local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
			self.aiThreshingTargetX = x;	
			self.aiThreshingTargetZ = z;	
			AICombine2.addCollisionTrigger(self, self);	
		end;	
		for _,implement in pairs(self.attachedImplements) do	
			if implement.object ~= nil then	
				if implement.object.needsLowering and implement.object.aiNeedsLowering then
					self:setJointMoveDown(implement.jointDescIndex, true, true)	
				end;	
				implement.object:aiTurnOn();	
				if self.isServer then	
					AICombine2.addCollisionTrigger(self, implement.object);	
				end;	
			end;
		end;	
		if self.threshingStartAnimation ~= nil and self.playAnimation ~= nil then	
			self:playAnimation(self.threshingStartAnimation, self.threshingStartAnimationSpeedScale, nil, true);
		end	
	
	self.waitingForDischarge = false;	
	self:setIsThreshing(true, true);	
	
	self.checkSpeedLimit = false;	
	self.waitingForWeather = false;	
	end;	
end;	
	
function AICombine2:stopAIThreshing(noEventSend)	
	if noEventSend == nil or noEventSend == false then	
		if g_server ~= nil then	
			g_server:broadcastEvent(AICombineSetStartedEvent:new(self, false), nil, nil, self);
		else	
			g_client:getServerConnection():sendEvent(AICombineSetStartedEvent:new(self, false));
		end;	
	end;	
	self:dismiss();	
	if self.isAIThreshing then	
		self.isAIThreshing = false;	
		self.allowsThreshing = true;	
		self.checkSpeedLimit = true;	
		self.waitingForWeather = false;	
		self:setIsThreshing(false, true);	
		if self.isServer then	
			--restore allowsThreshing flag	
			self.motor:setSpeedLevel(0, false);	
			self.motor.maxRpmOverride = nil;	
			WheelsUtil.updateWheelsPhysics(self, 0, self.lastSpeed, 0, false, self.requiredDriveMode);
			AICombine2.removeCollisionTrigger(self, self);	
		end;	
		for _,implement in pairs(self.attachedImplements) do	
			if implement.object ~= nil then	
				if implement.object.needsLowering and implement.object.aiNeedsLowering then
					self:setJointMoveDown(implement.jointDescIndex, false, true)	
				end;	
				AICombine2.removeCollisionTrigger(self, implement.object);	
				implement.object:aiTurnOff();	
			end	
		end;	
	
		if not self:getIsActive() then	
			self:onLeave();	
		end;	
	end;	
end;	
	
function AICombine2:onEnter(isControlling)	
end;	
	
function AICombine2:onLeave()	
end;	
	
function AICombine2.updateAIMovement(self, dt)	
	
	if not self:getIsAIThreshingAllowed() then	
		self:stopAIThreshing();	
		return;	
	end;	
	
	if not self.isControlled then	
		if g_currentMission.environment.needsLights then	
			self:setLightsVisibility(true);	
		else	
			self:setLightsVisibility(false);	
		end;	
	end;	
	
	local allowedToDrive = true;	
	if self.grainTankCapacity == 0 then	
		if not self.pipeStateIsUnloading[self.currentPipeState] then	
			allowedToDrive = false;	
		end	
		if not self.isPipeUnloading and (self.lastArea > 0 or self.lastLostGrainTankFillLevel > 0) then
			-- there is some fruit to unload, but there is no trailer. Stop and wait for a trailer
			self.waitingForTrailerToUnload = true;	
		end;	
	else	
		if self.grainTankFillLevel >= self.grainTankCapacity then	
			allowedToDrive = false;	
		end	
	end	
	
	if self.waitingForTrailerToUnload then	
		if self.lastValidGrainTankFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then	
			local trailer = self:findTrailerToUnload(self.lastValidGrainTankFruitType);
			if trailer ~= nil then	
				-- there is a trailer to unload. Continue working	
				self.waitingForTrailerToUnload = false;	
			end;	
		else	
			-- we did not cut anything yet. We shouldn't have ended in this state.Just continue working
			self.waitingForTrailerToUnload = false;	
		end;	
	end;	
	
	if (self.grainTankFillLevel >= self.grainTankCapacity and self.grainTankCapacity > 0) or self.waitingForTrailerToUnload or self.waitingForDischarge then
		allowedToDrive = false;	
	end;	
	for _,v in pairs(self.numCollidingVehicles) do	
		if v > 0 then	
			allowedToDrive = false;	
		break;	
		end;	
	end;	
	if self.turnStage > 0 then	
		if self.waitForTurnTime > self.time or (self.pipeIsUnloading and self.turnStage < 3) then
			allowedToDrive = false;	
		end;	
	end;	
	if not self:getIsThreshingAllowed(true) then	
		allowedToDrive = false;	
		self:setIsThreshing(false);	
		self.waitingForWeather = true;	
	else	
		if self.waitingForWeather then	
			if self.turnStage == 0 then	
				self.driveBackTime = self.time + self.driveBackTimeout;	
			end;	
			self:startThreshing();	
			self.waitingForWeather = false;	
		end;	
	end;	
	if not allowedToDrive then	
		--local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
		--local lx, lz = 0, 1; --AIVehicleUtil.getDriveDirection(self.aiTreshingDirectionNode, self.aiThreshingTargetX, y, self.aiThreshingTargetZ);
		--AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, FALSE, moveForwards, lx, lz)
		AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, nil, nil)
		return;	
	end;	
	
	local speedLevel = 2;	
	
	local leftMarker = self.aiLeftMarker;	
	local rightMarker = self.aiRightMarker;	
	local hasFruitPreparer = false;	
	local fruitType = self.lastValidInputFruitType;	
	if self.fruitPreparerFruitType ~= nil and self.fruitPreparerFruitType == fruitType then
		hasFruitPreparer = true;	
	end	
	for cutter,implement in pairs(self.attachedCutters) do	
		if cutter.aiLeftMarker ~= nil and leftMarker == nil then	
			leftMarker = cutter.aiLeftMarker;	
		end;	
		if cutter.aiRightMarker ~= nil and rightMarker == nil then	
			rightMarker = cutter.aiRightMarker;	
		end;	
		if Cutter.getUseLowSpeedLimit(cutter) then	
			speedLevel = 1;	
		end;	
	end;	
	
	if leftMarker == nil or rightMarker == nil then	
		self:stopAIThreshing();	
		return;	
	end;	
	
	if self.driveBackTime >= self.time then	
		local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
		local lx, lz = AIVehicleUtil.getDriveDirection(self.aiTreshingDirectionNode, self.aiThreshingTargetX, y, self.aiThreshingTargetZ);
		AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, true, false, lx, lz, speedLevel, 1)
		return;	
	end;	
	
	local hasArea = true;	
	if self.lastArea < 1 then	
		local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
		local dirX, dirZ = self.aiThreshingDirectionX, self.aiThreshingDirectionZ;	
		local lInX,  lInY,  lInZ = getWorldTranslation(leftMarker);	
		local rInX,  rInY,  rInZ = getWorldTranslation(rightMarker);	
		local heightX = lInX + dirX * self.frontAreaSize;	
		local heightZ = lInZ + dirZ * self.frontAreaSize;	
		local area = Utils.getFruitArea(fruitType, lInX, lInZ, rInX, rInZ, heightX, heightZ, hasFruitPreparer);
		if area < 1 then	
			hasArea = false;	
		end;	
	end;	
	if hasArea then	
		self.turnTimer = self.turnTimeout;	
	else	
		self.turnTimer = self.turnTimer - dt;	
	end;	
	
	
	local newTargetX, newTargetY, newTargetZ;	
		
	local moveForwards = true;	
	local updateWheels = true;	
	
	
	if self.turnTimer < 0 or self.turnStage > 0 then	
		if self.turnStage > 0 then				print("1");
			local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
			local dirX, dirZ = self.aiThreshingDirectionX, self.aiThreshingDirectionZ;
			local myDirX, myDirY, myDirZ = localDirectionToWorld(self.aiTreshingDirectionNode, 0, 0, 1);
	
			newTargetX = self.aiThreshingTargetX;	
			newTargetY = y;	
			newTargetZ = self.aiThreshingTargetZ;	
			if self.turnStage == 1 then	
				self.turnStageTimer = self.turnStageTimer - dt;	
				if self.lastSpeed < self.aiRescueSpeedThreshold then	
					self.aiRescueTimer = self.aiRescueTimer - dt;	
				else	
					self.aiRescueTimer = self.aiRescueTimeout;	
				end;	
				if myDirX*dirX + myDirZ*dirZ > self.turnStage1AngleCosThreshold or self.turnStageTimer < 0 or self.aiRescueTimer < 0 then
					self.turnStage = 2;	
					moveForwards = false;	
					if self.turnStageTimer < 0 or self.aiRescueTimer < 0 then	
	
						self.aiThreshingTargetBeforeSaveX = self.aiThreshingTargetX;
						self.aiThreshingTargetBeforeSaveZ = self.aiThreshingTargetZ;
	
						newTargetX = self.aiThreshingTargetBeforeTurnX;	
						newTargetZ = self.aiThreshingTargetBeforeTurnZ;	
	
						moveForwards = false;	
						self.turnStage = 4;	
						self.turnStageTimer = self.turnStage4Timeout;	
					else	
						self.turnStageTimer = self.turnStage2Timeout;	
					end;	
					self.aiRescueTimer = self.aiRescueTimeout;	
				end;	
			elseif self.turnStage == 2 then	
				self.turnStageTimer = self.turnStageTimer - dt;	
				if self.lastSpeed < self.aiRescueSpeedThreshold then	
					self.aiRescueTimer = self.aiRescueTimer - dt;	
				else	
					self.aiRescueTimer = self.aiRescueTimeout;	
				end;	
				if myDirX*dirX + myDirZ*dirZ > self.turnStage2AngleCosThreshold orself.turnStageTimer < 0 or self.aiRescueTimer < 0 then
					AICombine2.switchToTurnStage3(self);	
				else	
					moveForwards = false;	
				end;	
			elseif self.turnStage == 3 then	
				--[[if Utils.vector2Length(x-newTargetX, z-newTargetZ) < self.turnEndDistance then
				self.turnTimer = self.turnTimeoutLong;	
				self.turnStage = 0;	
				--print("turning done");	
				end;]]	
				if self.lastSpeed < self.aiRescueSpeedThreshold then	
					self.aiRescueTimer = self.aiRescueTimer - dt;	
				else	
					self.aiRescueTimer = self.aiRescueTimeout;	
				end;	
				local dx, dz = x-newTargetX, z-newTargetZ;	
				local dot = dx*dirX + dz*dirZ;	
				if -dot < self.turnEndDistance then	
					self.turnTimer = self.turnTimeoutLong;	
					self.turnStage = 0;	
				elseif self.aiRescueTimer < 0 then	
					self.aiThreshingTargetBeforeSaveX = self.aiThreshingTargetX;	
					self.aiThreshingTargetBeforeSaveZ = self.aiThreshingTargetZ;	
	
					newTargetX = self.aiThreshingTargetBeforeTurnX;	
					newTargetZ = self.aiThreshingTargetBeforeTurnZ;	
		
					moveForwards = false;	
					self.turnStage = 4;	
					self.turnStageTimer = self.turnStage4Timeout;	
				end;	
			elseif self.turnStage == 4 then	
				self.turnStageTimer = self.turnStageTimer - dt;	
				if self.lastSpeed < self.aiRescueSpeedThreshold then	
					self.aiRescueTimer = self.aiRescueTimer - dt;	
				else	
					self.aiRescueTimer = self.aiRescueTimeout;	
				end;	
				if self.aiRescueTimer < 0 then	
					self.aiRescueTimer = self.aiRescueTimeout;	
					local x,y,z = localDirectionToWorld(self.aiRescueNode, 0, 0, -1);
					local scale = self.aiRescueForce/Utils.vector2Length(x,z);	
					addForce(self.aiRescueNode, x*scale, 0, z*scale, 0, 0, 0, true);
				end;	
				if self.turnStageTimer < 0 then	
					self.aiRescueTimer = self.aiRescueTimeout;	
					self.turnStageTimer = self.turnStage1Timeout;	
					self.turnStage = 1;	
	
					newTargetX = self.aiThreshingTargetBeforeSaveX;	
					newTargetZ = self.aiThreshingTargetBeforeSaveZ;	
				else	
					local dirX, dirZ = -dirX, -dirZ;	
					-- just drive along direction	
					local targetX, targetZ = self.aiThreshingTargetX, self.aiThreshingTargetZ;
					local dx, dz = x-targetX, z-targetZ;	
					local dot = dx*dirX + dz*dirZ;	
	
					local projTargetX = targetX +dirX*dot;	
					local projTargetZ = targetZ +dirZ*dot;	
	
					newTargetX = projTargetX-dirX*self.lookAheadDistance;	
					newTargetZ = projTargetZ-dirZ*self.lookAheadDistance;	
					moveForwards = false;	
				end;	
			end;	
		elseif fruitType == FruitUtil.FRUITTYPE_UNKNOWN then	
			self:stopAIThreshing();	
			return;	
		else	
			-- turn	
	
			local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
			local dirX, dirZ = self.aiThreshingDirectionX, self.aiThreshingDirectionZ;
			local sideX, sideZ = -dirZ, dirX;	
			local lInX,  lInY,  lInZ = getWorldTranslation(leftMarker);	
			local rInX,  rInY,  rInZ = getWorldTranslation(rightMarker);	
				
			local threshWidth = Utils.vector2Length(lInX-rInX, lInZ-rInZ);	
			local turnLeft = true;	
				
			local lWidthX = x - sideX*0.5*threshWidth + dirX * self.sideWatchDirOffset;
			local lWidthZ = z - sideZ*0.5*threshWidth + dirZ * self.sideWatchDirOffset;
			local lStartX = lWidthX - sideX*0.7*threshWidth;	
			local lStartZ = lWidthZ - sideZ*0.7*threshWidth;	
			local lHeightX = lStartX + dirX*self.sideWatchDirSize;	
			local lHeightZ = lStartZ + dirZ*self.sideWatchDirSize;	
	
			local rWidthX = x + sideX*0.5*threshWidth + dirX * self.sideWatchDirOffset;
			local rWidthZ = z + sideZ*0.5*threshWidth + dirZ * self.sideWatchDirOffset;
			local rStartX = rWidthX + sideX*0.7*threshWidth;	
			local rStartZ = rWidthZ + sideZ*0.7*threshWidth;	
			local rHeightX = rStartX + dirX*self.sideWatchDirSize;	
			local rHeightZ = rStartZ + dirZ*self.sideWatchDirSize;	
		
			local leftFruit = Utils.getFruitArea(fruitType, lStartX, lStartZ, lWidthX, lWidthZ, lHeightX, lHeightZ, hasFruitPreparer);
			local rightFruit = Utils.getFruitArea(fruitType, rStartX, rStartZ, rWidthX, rWidthZ, rHeightX, rHeightZ, hasFruitPreparer);
			-- turn to where more fruit is to cut	
			if leftFruit > 0 or rightFruit > 0 then	
				if leftFruit > rightFruit then	
					turnLeft = true;	
				else	
					turnLeft = false;	
				end	
			else	
				self:stopAIThreshing();	
				return;	
			end;	
			local targetX, targetZ = self.aiThreshingTargetX, self.aiThreshingTargetZ;
			--local dx, dz = x-targetX, z-targetZ;	
			--local dot = dx*dirX + dz*dirZ;	
			--local x, z = targetX + dirX*dot, targetZ + dirZ*dot;	
			--threshWidth = threshWidth*self.aiTurnThreshWidthScale;	
			
	
	
			local markerSideOffset;	
			if turnLeft then	
				markerSideOffset, _, _ = worldToLocal(self.aiTreshingDirectionNode, lInX, lInY, lInZ);
			else	
				markerSideOffset, _, _ = worldToLocal(self.aiTreshingDirectionNode, rInX, rInY, rInZ);
			end	
			markerSideOffset = 2*markerSideOffset;	
		
			local areaOverlap = math.min(threshWidth*(1-self.aiTurnThreshWidthScale), self.aiTurnThreshWidthMaxDifference);
			if markerSideOffset > 0 then	
				markerSideOffset = math.max(markerSideOffset - areaOverlap, 0.01);	
			else	
				markerSideOffset = math.min(markerSideOffset + areaOverlap, -0.01);
			end	
		
			local x,z = Utils.projectOnLine(x, z, targetX, targetZ, dirX, dirZ)	
			newTargetX = x-sideX*markerSideOffset;	
			newTargetY = y;	
			newTargetZ = z-sideZ*markerSideOffset;	
		
			self.aiThreshingDirectionX = -dirX;	
			self.aiThreshingDirectionZ = -dirZ;	
			self.turnStage = 1;	
			self.aiRescueTimer = self.aiRescueTimeout;	
			self.turnStageTimer = self.turnStage1Timeout;	
		
			self.aiThreshingTargetBeforeTurnX = self.aiThreshingTargetX;	
			self.aiThreshingTargetBeforeTurnZ = self.aiThreshingTargetZ;	
		
			self.waitForTurnTime = self.time + self.waitForTurnTimeout;	
			self:setAIImplementsMoveDown(false);	
			-- do not thresh while turning	
			self.allowsThreshing = false;	
			updateWheels = false;	
			if turnLeft then	
				--print("turning left ", threshWidth);	
			else	
				--print("turning right ", threshWidth);	
			end;	
		end;	
	else	
		local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode);	
		local dirX, dirZ = self.aiThreshingDirectionX, self.aiThreshingDirectionZ;	
		-- just drive along direction	
		local targetX, targetZ = self.aiThreshingTargetX, self.aiThreshingTargetZ;	
		local dx, dz = x-targetX, z-targetZ;	
		local dot = dx*dirX + dz*dirZ;	
	
		local projTargetX = targetX +dirX*dot;	
		local projTargetZ = targetZ +dirZ*dot;	
	
		--print("old target: "..targetX.." ".. targetZ .. " distOnDir " .. dot.."proj: "..projTargetX.." "..projTargetZ);
		
		newTargetX = projTargetX+self.aiThreshingDirectionX*self.lookAheadDistance;
		newTargetY = y;	
		newTargetZ = projTargetZ+self.aiThreshingDirectionZ*self.lookAheadDistance;
		--print(distOnDir.." target: "..newTargetX.." ".. newTargetZ);	
	end;	
	
	if updateWheels then	
		local lx, lz = AIVehicleUtil.getDriveDirection(self.aiTreshingDirectionNode, newTargetX, newTargetY, newTargetZ);
		
		if self.turnStage == 2 and math.abs(lx) < 0.1 then	
			AICombine2.switchToTurnStage3(self);	
			moveForwards = true;	
		end;	
		
		AIVehicleUtil.driveInDirection(self, dt, 25, 0.5, 0.5, 20, true, moveForwards, lx, lz, speedLevel, 0.9);
		
		--local maxAngle = 0.785398163; --45;	
		local maxlx = 0.7071067; --math.sin(maxAngle);	
		local colDirX = lx;	
		local colDirZ = lz;	
		
		if colDirX > maxlx then	
			colDirX = maxlx;	
			colDirZ = 0.7071067; --math.cos(maxAngle);	
		elseif colDirX < -maxlx then	
			colDirX = -maxlx;	
			colDirZ = 0.7071067; --math.cos(maxAngle);	
		end;	
	
		for triggerId,_ in pairs(self.numCollidingVehicles) do	
			AIVehicleUtil.setCollisionDirection(self.aiTreshingDirectionNode, triggerId, colDirX, colDirZ);
		end;	
	end;	
		
	self.aiThreshingTargetX = newTargetX;	
	self.aiThreshingTargetZ = newTargetZ;	
end;	
	
function AICombine2.switchToDirection(self, myDirX, myDirZ)	
	self.aiThreshingDirectionX = myDirX;	
	self.aiThreshingDirectionZ = myDirZ;	
	--print("switch to direction");	
end;	
	
function AICombine2:setAIImplementsMoveDown(moveDown)	
	if self.isServer then	
		g_server:broadcastEvent(AISetImplementsMoveDownEvent:new(self, moveDown), nil, nil, self);
	end;	
	for _,implement in pairs(self.attachedImplements) do	
		if implement.object ~= nil then	
			if implement.object.needsLowering and implement.object.aiNeedsLowering then
				self:setJointMoveDown(implement.jointDescIndex, moveDown, true);	
			end;	
			if moveDown then	
				implement.object:aiLower();	
			else	
				implement.object:aiRaise();	
			end	
		end	
	end;	
	
	if self.threshingStartAnimation ~= nil and self.playAnimation ~= nil then	
		if moveDown then	
			self:playAnimation(self.threshingStartAnimation, self.threshingStartAnimationSpeedScale, nil, true);
		else	
			self:playAnimation(self.threshingStartAnimation, -self.threshingStartAnimationSpeedScale, nil, true);
		end	
	end	
end;	
	
function AICombine2.addCollisionTrigger(self, object)	
	if self.isServer then	
		if object.aiTrafficCollisionTrigger ~= nil then	
			addTrigger(object.aiTrafficCollisionTrigger, "onTrafficCollisionTrigger", self);
			self.numCollidingVehicles[object.aiTrafficCollisionTrigger] = 0;	
		end	
		if object ~= self then	
			for _,v in pairs(object.components) do	
				self.trafficCollisionIgnoreList[v.node] = true;	
			end	
		end	
	end	
end	
	
function AICombine2:removeCollisionTrigger(object)	
	if self.isServer then	
		if object.aiTrafficCollisionTrigger ~= nil then	
			removeTrigger(object.aiTrafficCollisionTrigger);	
			self.numCollidingVehicles[object.aiTrafficCollisionTrigger] = nil;	
		end	
		if object ~= self then	
			for _,v in pairs(object.components) do	
				self.trafficCollisionIgnoreList[v.node] = nil;	
			end	
		end	
	end	
end	
	
	
function AICombine2:attachImplement(implement)	
	local object = implement.object;	
	if object.attacherJoint.jointType == Vehicle.JOINTTYPE_CUTTER then	
		if self.isAIThreshing and self.isServer then	
			AICombine2.addCollisionTrigger(self, object);	
		end;	
	elseif object.attacherJoint.jointType == Vehicle.JOINTTYPE_TRAILER or object.attacherJoint.jointType == Vehicle.JOINTTYPE_TRAILERLOW then
		self.numAttachedTrailers = self.numAttachedTrailers+1;	
	end;	
end;	
	
function AICombine2:detachImplement(implementIndex)	
	local object = self.attachedImplements[implementIndex].object;	
	if object ~= nil then	
		if object.attacherJoint.jointType == Vehicle.JOINTTYPE_CUTTER then	
			if self.isAIThreshing and self.isServer then	
				AICombine2.removeCollisionTrigger(self, object);	
			end;	
		elseif object.attacherJoint.jointType == Vehicle.JOINTTYPE_TRAILER or object.attacherJoint.jointType == Vehicle.JOINTTYPE_TRAILERLOW then
			self.numAttachedTrailers = self.numAttachedTrailers-1;	
		end;	
	end	
end;	
	
function AICombine2:onTrafficCollisionTrigger(triggerId, otherId, onEnter, onLeave,	onStay, otherShapeId)
	if onEnter or onLeave then	
		if g_currentMission.players[otherId] ~= nil then	
			if onEnter then	
				self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1;
			elseif onLeave then	
				self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0);
			end;	
		else	
			local vehicle = g_currentMission.nodeToVehicle[otherId];	
			if vehicle ~= nil and self.trafficCollisionIgnoreList[otherId] == nil then
				if onEnter then	
					self.numCollidingVehicles[triggerId] = self.numCollidingVehicles[triggerId]+1;
				elseif onLeave then	
					self.numCollidingVehicles[triggerId] = math.max(self.numCollidingVehicles[triggerId]-1, 0);
				end;	
			end;	
		end;	
	end;	
end;	
	
function AICombine2.switchToTurnStage3(self)	
	self.turnStage = 3;	
	self:setAIImplementsMoveDown(true);	
	self.allowsThreshing = true;	
	self.aiRescueTimer = self.aiRescueTimeout;	
end;	
	
function AICombine2:canStartAIThreshing()	
	if g_currentMission.disableCombineAI then	
		return false;	
	end;	
	if not self:getIsStartThreshingAllowed() then	
		return false;	
	end	
	if self.numAttachedTrailers > 0 then	
		return false;	
	end;	
	if Hirable.numHirablesHired >= g_currentMission.maxNumHirables then	
		return false;	
	end;	
	return true;	
end;	
	
function AICombine2:getIsAIThreshingAllowed()	
	if g_currentMission.disableCombineAI then	
		return false;	
	end;	
	if not self:getIsStartThreshingAllowed() then	
		return false;	
	end	
	if self.numAttachedTrailers > 0 then	
		return false;	
	end;	
	return true;	
end;	
