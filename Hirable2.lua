--
-- Hirable2
-- Specialization for Hirable2 vehicles (eg bots)
--
-- @author  Stefan Geiger
-- @date  10/01/09
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

Hirable2 = {};

Hirable2.numHirablesHired = 0;

function Hirable2.prerequisitesPresent(specializations)
	return true;
end;

function Hirable2:load(xmlFile)


	self.hire = SpecializationUtil.callSpecializationsFunction("hire");
	self.dismiss = SpecializationUtil.callSpecializationsFunction("dismiss");

	self.pricePerMS = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pricePerHour"), 2000)/60/60/1000;
	self.isHired = false;
end;

function Hirable2:delete()
	self:dismiss();
end;

function Hirable2:mouseEvent(posX, posY, isDown, isUp, button)
end;

function Hirable2:keyEvent(unicode, sym, modifier, isDown)
end;

function Hirable2:update(dt)
	if self.isHired then
		self.forceIsActive = true;
		self.stopMotorOnLeave = false;
		self.steeringEnabled = false;
		self.deactivateOnLeave = false;

		if self.isServer then
			local difficultyMultiplier = Utils.lerp(0.6, 1, (g_currentMission.missionStats.difficulty-1)/2) -- range from 0.6 (easy)  to  1 (hard)
			g_currentMission:addSharedMoney(-dt*difficultyMultiplier*self.pricePerMS, "wagePayment");
		end;
	end;
end;

function Hirable2:draw()
end;

function Hirable2:hire()
	if not self.isHired then
		Hirable2.numHirablesHired = Hirable2.numHirablesHired + 1;
	end;
	self.isHired = true;

	self.forceIsActive = true;
	self.stopMotorOnLeave = false;
	self.steeringEnabled = false;
	self.deactivateOnLeave = false;
	self.disableCharacterOnLeave = false;
	
end;

function Hirable2:dismiss()
	if self.isHired then
		Hirable2.numHirablesHired = math.max(Hirable2.numHirablesHired - 1, 0);
	end;

	self.isHired = false;

	self.forceIsActive = false;
	self.stopMotorOnLeave = true;
	self.steeringEnabled = true;
	self.deactivateOnLeave = true;

	self.disableCharacterOnLeave = true;

	if not self.isEntered and not self.isControlled then
		if self.characterNode ~= nil then
			setVisibility(self.characterNode, false);
		end;
	end;

end;
