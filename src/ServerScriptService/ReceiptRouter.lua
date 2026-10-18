-- MarketplaceService.ProcessReceipt can only have one handler (owned by VipAuctionService).
-- Other services register Developer Product handlers here. A handler returns a ProductPurchaseDecision,
-- or nil when the product isn't theirs.

local ReceiptRouter = {}

local handlers = {}

function ReceiptRouter.Register(handler)
	table.insert(handlers, handler)
end

function ReceiptRouter.Handle(receipt)
	for _, handler in ipairs(handlers) do
		local decision = handler(receipt)
		if decision ~= nil then
			return decision
		end
	end
	return nil
end

return ReceiptRouter
