CREATE TABLE player_keychain(player_id INT NOT NULL, action_id INT NOT NULL, PRIMARY KEY(player_id,action_id));
CREATE TABLE personal_store_items(item_code INT AUTO_INCREMENT PRIMARY KEY,seller_guid INT NOT NULL,itemid INT NOT NULL,subtype INT DEFAULT 0,count INT NOT NULL,price BIGINT NOT NULL,attributes BLOB);
CREATE TABLE web_house_pending_transfers(id INT AUTO_INCREMENT PRIMARY KEY,house_id INT NOT NULL,to_player_id INT NOT NULL,status VARCHAR(40));
