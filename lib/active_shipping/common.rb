module ActiveMerchant  
  autoload :Connection,           'active_shipping/common/connection'
  autoload :Country,              'active_shipping/common/country'
  autoload :ActiveMerchantError,  'active_shipping/common/error'
  autoload :PostData,             'active_shipping/common/post_data'
  autoload :PostsData,            'active_shipping/common/posts_data'
  autoload :RequiresParameters,   'active_shipping/common/requires_parameters'
  autoload :Utils,                'active_shipping/common/utils'
  autoload :Validateable,         'active_shipping/common/validateable'
end