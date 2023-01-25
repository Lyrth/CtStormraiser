

local impl = require './jsonImpl'

impl._setRoot('storage')
impl._runBackground()


return impl
